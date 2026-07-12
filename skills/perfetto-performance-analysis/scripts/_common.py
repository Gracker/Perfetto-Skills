#!/usr/bin/env python3
from __future__ import annotations

import csv
from dataclasses import dataclass
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import time
from collections.abc import Callable, Mapping


DEFAULT_PERFETTO_VERSION = "v57.2"
DEFAULT_MAX_OUTPUT_BYTES = 16 * 1024 * 1024


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
    max_output_bytes: int = DEFAULT_MAX_OUTPUT_BYTES,
) -> QueryResult:
    if (sql is None) == (sql_file is None):
        raise ValueError("Provide exactly one of sql or sql_file")
    trace = Path(trace_path).expanduser().resolve()
    if not trace.is_file():
        raise FileNotFoundError(f"Trace file not found: {trace}")
    binary = resolve_trace_processor(trace_processor)
    if timeout <= 0:
        raise ValueError("timeout must be greater than zero")
    if max_output_bytes <= 0:
        raise ValueError("max_output_bytes must be greater than zero")

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
    stdout_path: Path | None = None
    stderr_path: Path | None = None
    process: subprocess.Popen[bytes] | None = None
    try:
        with tempfile.NamedTemporaryFile(mode="wb", delete=False) as stdout_file:
            stdout_path = Path(stdout_file.name)
            with tempfile.NamedTemporaryFile(mode="wb", delete=False) as stderr_file:
                stderr_path = Path(stderr_file.name)
                process = subprocess.Popen(
                    command,
                    stdout=stdout_file,
                    stderr=stderr_file,
                )
                deadline = time.monotonic() + timeout
                while process.poll() is None:
                    if time.monotonic() >= deadline:
                        process.kill()
                        process.wait()
                        raise QueryError(f"Trace query timed out after {timeout:g}s")
                    if (
                        stdout_path.stat().st_size > max_output_bytes
                        or stderr_path.stat().st_size > max_output_bytes
                    ):
                        process.kill()
                        process.wait()
                        raise QueryError(
                            f"Trace query exceeded the {max_output_bytes} byte output limit"
                        )
                    time.sleep(0.02)
        if (
            stdout_path.stat().st_size > max_output_bytes
            or stderr_path.stat().st_size > max_output_bytes
        ):
            raise QueryError(
                f"Trace query exceeded the {max_output_bytes} byte output limit"
            )
        stdout = stdout_path.read_text(encoding="utf-8", errors="replace")
        stderr = stderr_path.read_text(encoding="utf-8", errors="replace")
        returncode = process.returncode
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        if temporary_query is not None:
            temporary_query.unlink(missing_ok=True)
        if stdout_path is not None:
            stdout_path.unlink(missing_ok=True)
        if stderr_path is not None:
            stderr_path.unlink(missing_ok=True)

    result = QueryResult(
        stdout=stdout,
        stderr=stderr,
        returncode=returncode,
        command=command,
    )
    if returncode != 0:
        detail = stderr.strip() or stdout.strip()
        raise QueryError(
            f"trace_processor_shell exited with {returncode}: {detail}"
        )
    return result


def sql_literal(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("SQL parameters cannot contain NaN or infinity")
        return repr(value)
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    if isinstance(value, (list, tuple)):
        if not value:
            return "NULL"
        return ", ".join(sql_literal(item) for item in value)
    raise ValueError(f"unsupported SQL parameter type: {type(value).__name__}")


def sql_string_fragment(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float, str)):
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("SQL parameters cannot contain NaN or infinity")
        return str(value).replace("'", "''")
    if isinstance(value, (list, tuple)):
        return ",".join(sql_string_fragment(item) for item in value)
    raise ValueError(f"unsupported SQL string parameter type: {type(value).__name__}")


def default_template_value(raw: str) -> object:
    if raw == "" or raw == "''" or raw == '""':
        return ""
    if raw.upper() == "NULL":
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def result_rows_to_relation(value: object, name: str) -> str:
    if isinstance(value, dict) and isinstance(value.get("rows"), list):
        value = value["rows"]
    if not isinstance(value, list) or not value:
        raise ValueError(f"saved result {name!r} must contain at least one row")
    if not all(isinstance(row, dict) for row in value):
        raise ValueError(f"saved result {name!r} must be an array of objects")
    rows: list[dict[str, object]] = value
    columns = sorted({str(column) for row in rows for column in row})
    if not columns:
        raise ValueError(f"saved result {name!r} has no columns")
    selects = []
    for row in rows:
        fields = [
            f"{sql_literal(row.get(column))} AS {quote_identifier(column)}"
            for column in columns
        ]
        selects.append("SELECT " + ", ".join(fields))
    return "(" + " UNION ALL ".join(selects) + ")"


_RESULT_FIELD = re.compile(r"\.([A-Za-z_][A-Za-z0-9_]*)")
_RESULT_INDEX = re.compile(r"\[(0|[1-9][0-9]*)\]")


def resolve_result_expression(
    expression: str, results: Mapping[str, object]
) -> tuple[bool, bool, object]:
    """Resolve a pipeline-style result path.

    Returns ``(matched, is_relation, value)``. A bare result name denotes the
    complete row relation; dotted fields and numeric indexes select a scalar.
    ``data`` and ``rows`` are accepted as aliases for a top-level row array so
    exported SmartPerfetto expressions keep their documented shape.
    """
    root = next(
        (
            name
            for name in sorted(results, key=len, reverse=True)
            if expression == name
            or expression.startswith(name + ".")
            or expression.startswith(name + "[")
        ),
        None,
    )
    if root is None:
        return False, False, None
    if expression == root:
        return True, True, results[root]

    value = results[root]
    offset = len(root)
    while offset < len(expression):
        field_match = _RESULT_FIELD.match(expression, offset)
        if field_match:
            field = field_match.group(1)
            if isinstance(value, list) and field in {"data", "rows"}:
                pass
            elif isinstance(value, dict) and field in value:
                value = value[field]
            elif isinstance(value, dict) and field == "data" and "rows" in value:
                value = value["rows"]
            else:
                raise ValueError(
                    f"saved result path {expression!r} has no field {field!r}"
                )
            offset = field_match.end()
            continue

        index_match = _RESULT_INDEX.match(expression, offset)
        if index_match:
            index = int(index_match.group(1))
            if not isinstance(value, list):
                raise ValueError(
                    f"saved result path {expression!r} indexes a non-array value"
                )
            if index >= len(value):
                raise ValueError(
                    f"saved result path {expression!r} index {index} is out of range"
                )
            value = value[index]
            offset = index_match.end()
            continue

        raise ValueError(f"invalid saved result path: {expression!r}")
    if isinstance(value, (dict, list, tuple)):
        raise ValueError(f"saved result path {expression!r} does not resolve to a scalar")
    return True, False, value


def render_sql_template(
    template: str,
    parameters: Mapping[str, object],
    results: Mapping[str, object],
) -> str:
    output: list[str] = []
    index = 0
    state = "normal"
    while index < len(template):
        if state == "line_comment":
            output.append(template[index])
            if template[index] == "\n":
                state = "normal"
            index += 1
            continue
        if state == "block_comment":
            if template.startswith("*/", index):
                output.append("*/")
                index += 2
                state = "normal"
            else:
                output.append(template[index])
                index += 1
            continue
        if state == "normal" and template.startswith("--", index):
            output.append("--")
            index += 2
            state = "line_comment"
            continue
        if state == "normal" and template.startswith("/*", index):
            output.append("/*")
            index += 2
            state = "block_comment"
            continue
        if template.startswith("${", index):
            end = template.find("}", index + 2)
            if end < 0:
                raise ValueError("unterminated SQL template placeholder")
            expression = template[index + 2 : end]
            name, separator, raw_default = expression.partition("|")
            if not name:
                raise ValueError("empty SQL template placeholder")
            matched_result, is_relation, result_value = resolve_result_expression(
                name, results
            )
            if matched_result:
                if is_relation:
                    if state == "string":
                        raise ValueError(
                            f"saved result {name!r} cannot be used inside a string"
                        )
                    replacement = result_rows_to_relation(result_value, name)
                else:
                    replacement = (
                        sql_string_fragment(result_value)
                        if state == "string"
                        else sql_literal(result_value)
                    )
            else:
                if name in parameters:
                    value = parameters[name]
                elif separator:
                    value = default_template_value(raw_default)
                else:
                    raise ValueError(f"missing SQL template value: {name}")
                replacement = (
                    sql_string_fragment(value) if state == "string" else sql_literal(value)
                )
            output.append(replacement)
            index = end + 1
            continue
        if state == "string":
            if template.startswith("''", index):
                output.append("''")
                index += 2
                continue
            if template[index] == "'":
                state = "normal"
        elif template[index] == "'":
            state = "string"
        output.append(template[index])
        index += 1
    return "".join(output)


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


def _parse_relaxed_perfetto_json_row(
    line: str, fieldnames: list[str]
) -> list[str]:
    """Parse trace_processor CSV fields whose JSON quotes are not doubled.

    trace_processor_shell quotes a JSON result column as a CSV field but leaves
    the JSON object's own quotes unescaped. Recovery is deliberately limited to
    columns named ``*_json`` and accepts a boundary only when the candidate is
    valid JSON, so arbitrary malformed/free-text output remains rejected.
    """
    values: list[str] = []
    offset = 0
    for field_index, fieldname in enumerate(fieldnames):
        last = field_index == len(fieldnames) - 1
        if offset >= len(line):
            raise QueryError("trace_processor_shell returned a truncated CSV row")
        if line[offset] != '"':
            end = len(line) if last else line.find(",", offset)
            if end < 0:
                raise QueryError("trace_processor_shell returned a malformed CSV row")
            values.append(line[offset:end])
            offset = end + (0 if last else 1)
            continue
        start = offset + 1
        if fieldname.endswith("_json") or line[start:start + 1] in {"[", "{"}:
            cursor = start
            recovered_json = False
            while True:
                cursor = line.find('"', cursor)
                if cursor < 0:
                    break
                boundary = cursor == len(line) - 1 if last else line.startswith('",', cursor)
                if boundary:
                    candidate = line[start:cursor]
                    try:
                        json.loads(candidate)
                    except json.JSONDecodeError:
                        cursor += 1
                        continue
                    values.append(candidate)
                    offset = cursor + (1 if last else 2)
                    recovered_json = True
                    break
                cursor += 1
            if recovered_json:
                continue
            if fieldname.endswith("_json"):
                raise QueryError("trace_processor_shell returned unterminated JSON CSV")
        cursor = start
        decoded: list[str] = []
        while cursor < len(line):
            if line.startswith('""', cursor):
                decoded.append('"')
                cursor += 2
                continue
            if line[cursor] == '"':
                boundary = cursor == len(line) - 1 if last else line.startswith('",', cursor)
                if boundary:
                    values.append("".join(decoded))
                    offset = cursor + (1 if last else 2)
                    break
            decoded.append(line[cursor])
            cursor += 1
        else:
            raise QueryError("trace_processor_shell returned unterminated CSV text")
    if offset != len(line):
        raise QueryError("trace_processor_shell returned extra CSV fields")
    return values


def parse_csv_output(output: str) -> list[dict[str, str | int | float | None]]:
    if not output.strip():
        return []
    reader = csv.DictReader(io.StringIO(output.lstrip("\r\n")))
    if reader.fieldnames is None:
        raise QueryError("trace_processor_shell returned CSV without a header")
    parsed: list[dict[str, str | int | float | None]] = []
    invalid = False
    for row in reader:
        if not row:
            continue
        if None in row or any(value is None for value in row.values()):
            invalid = True
            break
        parsed.append({key: parse_scalar(value) for key, value in row.items()})
    if invalid:
        lines = [line for line in output.lstrip("\r\n").splitlines() if line]
        header = next(csv.reader([lines[0]]))
        try:
            recovered = [
                _parse_relaxed_perfetto_json_row(line, header) for line in lines[1:]
            ]
            return [
                {key: parse_scalar(value) for key, value in zip(header, row, strict=True)}
                for row in recovered
            ]
        except QueryError:
            pass
        raise QueryError(
            "trace_processor_shell returned non-tabular text inside CSV; "
            "use raw/csv output or hex-encode free-text SQL columns before "
            "requesting JSON"
        )
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
