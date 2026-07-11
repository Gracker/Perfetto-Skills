#!/usr/bin/env python3
from __future__ import annotations

import csv
from dataclasses import dataclass
import hashlib
import io
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
from collections.abc import Callable, Mapping


DEFAULT_PERFETTO_VERSION = "v57.1"


class QueryError(RuntimeError):
    """Raised when trace_processor_shell rejects or cannot execute a query."""


@dataclass(frozen=True)
class QueryResult:
    stdout: str
    stderr: str
    returncode: int
    command: tuple[str, ...]


def runtime_platform_key(
    system: str | None = None, machine: str | None = None
) -> str:
    normalized_system = (system or platform.system()).strip().lower()
    normalized_machine = (machine or platform.machine()).strip().lower()
    aliases = {
        ("darwin", "arm64"): "mac-arm64",
        ("darwin", "aarch64"): "mac-arm64",
        ("darwin", "x86_64"): "mac-amd64",
        ("darwin", "amd64"): "mac-amd64",
        ("linux", "x86_64"): "linux-amd64",
        ("linux", "amd64"): "linux-amd64",
        ("linux", "arm64"): "linux-arm64",
        ("linux", "aarch64"): "linux-arm64",
        ("windows", "x86_64"): "windows-amd64",
        ("windows", "amd64"): "windows-amd64",
    }
    try:
        return aliases[(normalized_system, normalized_machine)]
    except KeyError as exc:
        raise RuntimeError(
            f"Unsupported platform: {system or platform.system()} "
            f"{machine or platform.machine()}"
        ) from exc


def default_cache_root(env: Mapping[str, str] | None = None) -> Path:
    values = os.environ if env is None else env
    if values.get("PERFETTO_SKILLS_CACHE"):
        return Path(values["PERFETTO_SKILLS_CACHE"]).expanduser()
    if values.get("XDG_CACHE_HOME"):
        return Path(values["XDG_CACHE_HOME"]).expanduser() / "perfetto-skills"
    if platform.system() == "Windows" and values.get("LOCALAPPDATA"):
        return Path(values["LOCALAPPDATA"]).expanduser() / "PerfettoSkills" / "Cache"
    return Path.home() / ".cache" / "perfetto-skills"


def default_cache_binary(
    version: str = DEFAULT_PERFETTO_VERSION,
    platform_name: str | None = None,
    env: Mapping[str, str] | None = None,
) -> Path:
    key = platform_name or runtime_platform_key()
    filename = "trace_processor_shell.exe" if key == "windows-amd64" else "trace_processor_shell"
    return default_cache_root(env) / "trace_processor" / version / key / filename


def _usable_executable(candidate: str | Path | None) -> Path | None:
    if not candidate:
        return None
    path = Path(candidate).expanduser().resolve()
    if path.is_file() and os.access(path, os.X_OK):
        return path
    return None


def resolve_trace_processor(
    explicit: str | None = None,
    *,
    env: Mapping[str, str] | None = None,
    path_lookup: Callable[[str], str | None] | None = None,
    cache_binary: Path | None = None,
) -> Path:
    values = os.environ if env is None else env
    lookup = shutil.which if path_lookup is None else path_lookup
    candidates: tuple[str | Path | None, ...] = (
        explicit,
        values.get("PERFETTO_TRACE_PROCESSOR"),
        lookup("trace_processor_shell"),
        cache_binary or default_cache_binary(env=values),
    )
    for candidate in candidates:
        executable = _usable_executable(candidate)
        if executable is not None:
            return executable
    raise FileNotFoundError(
        "trace_processor_shell not found; provide --trace-processor, set "
        "PERFETTO_TRACE_PROCESSOR, add it to PATH, or run "
        "bootstrap_trace_processor.py"
    )


def run_query(
    trace_path: str | Path,
    *,
    sql: str | None = None,
    sql_file: str | Path | None = None,
    trace_processor: str | None = None,
    timeout: float = 120.0,
) -> QueryResult:
    if (sql is None) == (sql_file is None):
        raise ValueError("Provide exactly one of sql or sql_file")
    trace = Path(trace_path).expanduser().resolve()
    if not trace.is_file():
        raise FileNotFoundError(f"Trace file not found: {trace}")
    binary = resolve_trace_processor(trace_processor)

    temporary_query: Path | None = None
    if sql_file is None:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".sql", delete=False
        ) as handle:
            handle.write(sql or "")
            temporary_query = Path(handle.name)
        query_path = temporary_query
    else:
        query_path = Path(sql_file).expanduser().resolve()
        if not query_path.is_file():
            raise FileNotFoundError(f"SQL file not found: {query_path}")

    command = (
        str(binary),
        "query",
        "--extra-checks",
        "--query-file",
        str(query_path),
        str(trace),
    )
    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise QueryError(f"Trace query timed out after {timeout:g}s") from exc
    finally:
        if temporary_query is not None:
            temporary_query.unlink(missing_ok=True)

    result = QueryResult(
        stdout=completed.stdout,
        stderr=completed.stderr,
        returncode=completed.returncode,
        command=command,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise QueryError(
            f"trace_processor_shell exited with {completed.returncode}: {detail}"
        )
    return result


_INTEGER = re.compile(r"^-?(?:0|[1-9][0-9]*)$")
_FLOAT = re.compile(
    r"^-?(?:[0-9]+\.[0-9]*|[0-9]*\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
)


def parse_scalar(value: str) -> str | int | float | None:
    if value == "[NULL]":
        return None
    if _INTEGER.fullmatch(value):
        return int(value)
    if _FLOAT.fullmatch(value):
        return float(value)
    return value


def parse_csv_output(output: str) -> list[dict[str, str | int | float | None]]:
    if not output.strip():
        return []
    reader = csv.DictReader(io.StringIO(output))
    if reader.fieldnames is None:
        raise QueryError("trace_processor_shell returned CSV without a header")
    parsed: list[dict[str, str | int | float | None]] = []
    for row in reader:
        if not row:
            continue
        if None in row or any(value is None for value in row.values()):
            raise QueryError(
                "trace_processor_shell returned non-tabular text inside CSV; "
                "use raw/csv output or hex-encode free-text SQL columns before "
                "requesting JSON"
            )
        parsed.append({key: parse_scalar(value) for key, value in row.items()})
    return parsed


def sha256_file(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_text_atomic(path: str | Path, content: str) -> Path:
    destination = Path(path).expanduser().resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=destination.parent,
            delete=False,
        ) as handle:
            temporary = Path(handle.name)
            handle.write(content)
        os.replace(temporary, destination)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return destination
