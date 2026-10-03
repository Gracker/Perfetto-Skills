#!/usr/bin/env python3
from __future__ import annotations

import csv
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import re
import queue
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import threading
import time
import weakref
from collections.abc import Callable, Iterable, Iterator, Mapping, Sequence
from typing import Any, TypeVar


TRACE_PROCESSOR_LOCK = Path(__file__).resolve().parents[1] / "references" / "trace-processor-lock.json"
DEFAULT_MAX_OUTPUT_BYTES = 16 * 1024 * 1024


class QueryError(RuntimeError):
    """Raised when trace_processor_shell rejects or cannot execute a query."""


@dataclass(frozen=True)
class QueryResult:
    stdout: str
    stderr: str
    returncode: int
    command: tuple[str, ...]
    # Rows of the single result set as read over RPC; None for CLI output.
    rows: tuple[Mapping[str, str | int | float | None], ...] | None = None


@dataclass(frozen=True, eq=False)
class RuntimeProcessScope:
    """An in-process binding; serialized fields cannot reissue its authority."""

    kind: str
    trace_sha256: str
    trace_side: str
    target: str | None
    selectors: tuple[tuple[str, object], ...]
    name_parameters: tuple[str, ...]
    roles: tuple[str, ...]


_issued_process_scopes: weakref.WeakSet[RuntimeProcessScope] = weakref.WeakSet()
PROCESS_SCOPE_ROLES = frozenset({"target", "global_context", "peer_context", "identity_metadata"})


def validate_process_scope_declaration(declaration: object) -> str:
    if not isinstance(declaration, Mapping) or set(declaration) - {
        "role", "binding", "context_fields", "exact_unavailable", "limitations",
    }:
        raise ValueError("invalid process scope declaration")
    role = declaration.get("role")
    if not isinstance(role, str) or role not in PROCESS_SCOPE_ROLES:
        raise ValueError("unknown process scope role")
    if "exact_unavailable" in declaration and (
        not isinstance(declaration["exact_unavailable"], str) or not declaration["exact_unavailable"].strip()
    ):
        raise ValueError("exact_unavailable requires an authored reason")
    if role == "target":
        if "binding" in declaration and (
            not isinstance(declaration["binding"], str)
            or declaration["binding"] not in {"native_upid", "effective_target_processes"}
        ):
            raise ValueError("unsupported target binding")
        if "binding" not in declaration and "exact_unavailable" not in declaration:
            raise ValueError("target scope requires binding or explicit unavailability")
    elif "binding" in declaration:
        raise ValueError("context scope cannot claim a target binding")
    fields = declaration.get("context_fields", {})
    if not isinstance(fields, Mapping) or any(
        name not in PROCESS_SCOPE_ROLES - {"target"}
        or not isinstance(values, list)
        or any(not isinstance(value, str) or not value.strip() for value in values)
        for name, values in fields.items()
    ):
        raise ValueError("invalid context fields")
    limitations = declaration.get("limitations", [])
    if not isinstance(limitations, list) or any(not isinstance(value, str) or not value.strip() for value in limitations):
        raise ValueError("invalid scope limitations")
    return role


def template_root(name: str) -> str:
    """The variable a placeholder name reads: `step` in `step.data[0].x`."""
    return re.split(r"[.\[]", name, maxsplit=1)[0]


def is_process_scope_name(name: object) -> bool:
    return isinstance(name, str) and template_root(name) == "__process_scope"


def reject_process_scope_names(values: Mapping[str, object]) -> None:
    if any(is_process_scope_name(name) for name in values):
        raise ValueError("reserved runtime process scope cannot be supplied as data")


def sql_template_expressions(template: str) -> set[str]:
    """Read complete placeholders, including quoted values but excluding comments."""
    expressions: set[str] = set()
    for match in re.finditer(r"--[^\n]*|/\*.*?\*/|'(?:''|[^'])*'|\$\{[^}]*\}", template, re.DOTALL):
        token = match.group(0)
        if token.startswith(("--", "/*")):
            continue
        expressions.update(re.findall(r"\$\{([^}]*)\}", token))
    return expressions


def sql_template_names(template: str) -> set[str]:
    return {expression.partition("|")[0] for expression in sql_template_expressions(template)}


def runtime_sql_bindings(template: str) -> list[str]:
    bindings: set[str] = set()
    for expression in sql_template_expressions(template):
        name, separator, _default = expression.partition("|")
        if is_process_scope_name(name):
            if name != "__process_scope.upid" or separator:
                raise ValueError("unsupported runtime process scope placeholder")
            bindings.add(name)
    return sorted(bindings)


def bind_runtime_process_scope(
    identity_result: Mapping[str, object],
    *,
    identity_policy: Mapping[str, object],
    parameters: Mapping[str, object],
    supplied_parameters: Mapping[str, object],
    name_parameters: list[str],
    trace_sha256: str,
    trace_side: str,
    scope_roles: tuple[str, ...] = ("target",),
) -> RuntimeProcessScope:
    reject_process_scope_names(parameters)
    reject_process_scope_names(supplied_parameters)
    if not scope_roles or any(not isinstance(role, str) or role not in PROCESS_SCOPE_ROLES for role in scope_roles):
        raise ValueError("invalid process scope roles")
    if not re.fullmatch(r"[0-9a-f]{64}", trace_sha256) or not trace_side:
        raise ValueError("runtime process scope requires current trace identity")
    for selector in ("upid", "pid"):
        # A null selector is no selector, as in SmartPerfetto's identity gate.
        if supplied_parameters.get(selector) is not None:
            raise ValueError("explicit process selectors are unsupported by the portable scope binding")
        if parameters.get(selector) not in (None, 0):
            raise ValueError("exact process scope is unsupported")
    policy = identity_policy.get("policy")
    aliases = identity_policy.get("aliases", [])
    if not isinstance(aliases, list) or not all(isinstance(name, str) for name in aliases):
        raise ValueError("invalid identity aliases")
    selector_names = sorted(set(aliases) | set(name_parameters) | {"upid", "pid"})
    names = set(aliases) | set(name_parameters)
    values = {name: parameters.get(name) for name in names if parameters.get(name) not in (None, "")}
    status = identity_result.get("status")
    target = identity_result.get("target")
    # The identity gate admits an unverified name only when the resolver itself
    # failed under verify_if_present; the scope then follows the requested name
    # and the run's identity record stays unresolved.
    admitted_unverified = (
        status == "unresolved" and bool(identity_result.get("gate_warning")) and policy == "verify_if_present"
    )
    if status == "resolved" or admitted_unverified:
        if policy not in {"required", "verify_if_present"} or not isinstance(target, str) or not target:
            raise ValueError("named process scope requires resolved identity")
        if "target" in scope_roles and not any(parameters.get(name) == target for name in name_parameters):
            raise ValueError("named process scope requires a consumed target name")
        if any(value != target for value in values.values()):
            raise ValueError("conflicting process names")
        kind = "named"
    elif (
        status == "not_requested" and policy == "verify_if_present"
        or status == "exempt" and policy in {"none", "exempt"}
    ) and not values:
        kind, target = "unscoped", None
    else:
        raise ValueError("process scope identity is unavailable")
    scope = RuntimeProcessScope(
        kind, trace_sha256, trace_side, target,
        tuple((name, parameters.get(name)) for name in selector_names),
        tuple(name_parameters),
        tuple(scope_roles),
    )
    _issued_process_scopes.add(scope)
    return scope


def _process_scope_value(
    scope: RuntimeProcessScope | None,
    parameters: Mapping[str, object],
    results: Mapping[str, object],
    template_names: set[str],
    trace_sha256: str | None,
    trace_side: str | None,
) -> None:
    if not isinstance(scope, RuntimeProcessScope) or scope not in _issued_process_scopes:
        raise ValueError("runtime-issued process scope is required")
    if scope.trace_sha256 != trace_sha256 or scope.trace_side != trace_side:
        raise ValueError("process scope trace or side mismatch")
    if any(parameters.get(name) != value for name, value in scope.selectors):
        raise ValueError("process scope selectors changed after binding")
    if any(name in results for name, _value in scope.selectors):
        raise ValueError("saved results cannot shadow process scope selectors")
    if scope.kind == "named" and "target" in scope.roles and not any(
        name in template_names and parameters.get(name) == scope.target
        for name in scope.name_parameters
    ):
        raise ValueError("named process scope requires its SQL name parameter")
    # Only target measurements require a name predicate. Context declarations
    # retain their role; resolved run identity does not make their rows targets.
    return None


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


def locked_trace_processor_revision() -> str:
    """The revision bootstrap_trace_processor.py installs into the cache."""
    return str(json.loads(TRACE_PROCESSOR_LOCK.read_text(encoding="utf-8"))["revision"])


def default_cache_binary(
    version: str | None = None,
    platform_name: str | None = None,
    env: Mapping[str, str] | None = None,
) -> Path:
    version = version or locked_trace_processor_revision()
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

    query_path: Path | None = None
    if sql_file is not None:
        query_path = Path(sql_file).expanduser().resolve()
        if not query_path.is_file():
            raise FileNotFoundError(f"SQL file not found: {query_path}")
    limits = _ProcessorLimits(time.monotonic() + timeout, timeout, max_output_bytes)
    try:
        text = sql if query_path is None else query_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = None
    result: QueryResult | None = None
    session = _active_session(trace, binary)
    if text is not None and session is not None and not session.unavailable:
        plan = _session_plan(text)
        if plan is not None:
            result = session.run(plan, limits)
    if result is None and text is not None and _RPC_SUPPORTED and (binary, trace) not in _RPC_UNAVAILABLE:
        result = _run_rpc_once(binary, trace, text, limits)
    if result is None:
        result = _run_processor(
            (str(binary), "query", "--extra-checks"),
            (str(trace),),
            sql=sql,
            sql_file=query_path,
            limits=limits,
        )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise QueryError(
            f"trace_processor_shell exited with {result.returncode}: {detail}"
        )
    return result


@dataclass(frozen=True)
class _ProcessorLimits:
    deadline: float
    timeout: float
    max_output_bytes: int

    def timed_out(self) -> QueryError:
        return QueryError(f"Trace query timed out after {self.timeout:g}s")

    def over_limit(self) -> QueryError:
        return QueryError(f"Trace query exceeded the {self.max_output_bytes} byte output limit")


def query_rows(result: QueryResult) -> list[dict[str, str | int | float | None]]:
    """A query's rows: the RPC cells when read over RPC, else the parsed CLI CSV."""
    return [dict(row) for row in result.rows] if result.rows is not None else parse_csv_output(result.stdout)


def _run_processor(
    head: tuple[str, ...],
    tail: tuple[str, ...] = (),
    *,
    sql: str | None,
    sql_file: Path | None,
    limits: _ProcessorLimits,
) -> QueryResult:
    """Run `head --query-file SQL tail` (the CLI fallback); `sql` goes through a temporary file."""
    temporary_query: Path | None = None
    if sql_file is None:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".sql", delete=False
        ) as handle:
            handle.write(sql or "")
            temporary_query = Path(handle.name)
        sql_file = temporary_query
    command = (*head, "--query-file", str(sql_file), *tail)
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
                while True:
                    try:
                        process.wait(timeout=0.02)
                        break
                    except subprocess.TimeoutExpired:
                        pass
                    if time.monotonic() >= limits.deadline:
                        process.kill()
                        process.wait()
                        raise limits.timed_out()
                    if (
                        stdout_path.stat().st_size > limits.max_output_bytes
                        or stderr_path.stat().st_size > limits.max_output_bytes
                    ):
                        process.kill()
                        process.wait()
                        raise limits.over_limit()
        if (
            stdout_path.stat().st_size > limits.max_output_bytes
            or stderr_path.stat().st_size > limits.max_output_bytes
        ):
            raise limits.over_limit()
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
    return QueryResult(stdout=stdout, stderr=stderr, returncode=returncode, command=command)


# ---------------------------------------------------------------------------
# trace_processor_shell RPC over stdio.
#
# `query` prints doubles with "%f" (six decimals, so 1e-7 prints 0.000000) and
# does not escape quotes or newlines in strings. `server stdio` serves the
# TraceProcessorRpc protocol (protos/perfetto/trace_processor/
# trace_processor.proto) on stdin/stdout and returns typed cells. Statements run
# one per TPM_STATEMENT_STREAMING request, as the CLI runs them, and an error
# carries the CLI's own traceback text and SQL positions. The child exits when
# its stdin closes, which also happens when this process dies.
# ---------------------------------------------------------------------------
_TPM_STATEMENT_STREAMING = 20
_RPC_UNAVAILABLE: set[tuple[Path, Path]] = set()
_RPC_READ_CHUNK = 1 << 16
# At most this many unread stdout chunks are buffered; the reader then blocks
# and the processor with it, so a fast producer cannot outrun memory.
_RPC_QUEUED_CHUNKS = 16
_STDERR_TAIL = 4000
# The processor runs under a small guardian that is its parent: the guardian
# kills it, through the handle it alone holds, as soon as this process dies,
# even in the middle of a query, so nothing outlives its owner. The guardian
# and the processor share one process group, which this process kills as a
# whole before reaping the guardian, so the group ID cannot have been reused.
_RPC_GUARDIAN = """
import os, subprocess, sys, time
owner = int(sys.argv[1])
if os.getppid() != owner:
    sys.exit(0)
child = subprocess.Popen(sys.argv[2:])
null = os.open(os.devnull, os.O_RDWR)
for fd in (0, 1, 2):
    os.dup2(null, fd)
while child.poll() is None:
    if os.getppid() != owner:
        child.kill()
        child.wait()
        break
    time.sleep(0.1)
sys.exit(child.returncode if child.returncode and child.returncode > 0 else 0)
"""
# stdio RPC needs the POSIX guardian; Windows uses the CLI (and its doubles).
_RPC_SUPPORTED = os.name != "nt"


class _RpcUnavailable(Exception):
    """The processor did not answer stdio RPC; the CLI path is used instead."""


def _malformed(detail: str) -> QueryError:
    return QueryError(f"trace_processor_shell RPC sent a malformed response: {detail}")


def _pb_varint(value: int) -> bytes:
    value &= (1 << 64) - 1
    out = bytearray()
    while True:
        low = value & 0x7F
        value >>= 7
        if value:
            out.append(low | 0x80)
        else:
            out.append(low)
            return bytes(out)


def _pb_read_varint(data: bytes | bytearray, index: int) -> tuple[int, int]:
    """Decode a varint at `index`; IndexError when the data ends inside it."""
    shift = value = 0
    while True:
        byte = data[index]
        index += 1
        value |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80:
            return value, index
        if shift > 63:
            raise _malformed("varint longer than 64 bits")


def _pb_fields(data: bytes) -> Iterator[tuple[int, int, Any]]:
    index = 0
    try:
        while index < len(data):
            key, index = _pb_read_varint(data, index)
            number, wire = key >> 3, key & 7
            if wire == 0:
                value, index = _pb_read_varint(data, index)
            elif wire in (1, 2, 5):
                if wire == 2:
                    size, index = _pb_read_varint(data, index)
                else:
                    size = 8 if wire == 1 else 4
                if index + size > len(data):
                    raise _malformed("field runs past the end of its message")
                value, index = data[index:index + size], index + size
            else:
                raise _malformed(f"wire type {wire}")
            yield number, wire, value
    except IndexError as error:
        raise _malformed("truncated varint") from error


def _pb_typed_fields(data: bytes, wires: Mapping[int, tuple[int, ...]]) -> Iterator[tuple[int, int, Any]]:
    """_pb_fields, rejecting a known field sent with a wire type it cannot have."""
    for number, wire, value in _pb_fields(data):
        if number in wires and wire not in wires[number]:
            raise _malformed(f"field {number} has wire type {wire}")
        yield number, wire, value


# Wire types of the fields read from TraceProcessorRpc, StatementResult,
# QueryResult and QueryResult.CellsBatch (packed repeated fields may arrive
# unpacked).
_RPC_WIRES = {4: (0,), 5: (2,), 219: (2,)}
_STATEMENT_WIRES = {1: (2,), 2: (0,), 3: (0,)}
_RESULT_WIRES = {1: (2,), 2: (2,), 3: (2,), 5: (0,)}
_BATCH_WIRES = {1: (0, 2), 2: (0, 2), 3: (1, 2), 4: (2,), 5: (2,), 6: (0,)}


def _pb_packed_varints(value: Any, wire: int) -> list[int]:
    if wire == 0:
        return [value]
    values, index = [], 0
    try:
        while index < len(value):
            item, index = _pb_read_varint(value, index)
            values.append(item)
    except IndexError as error:
        raise _malformed("truncated packed varint") from error
    return values


def _pb_bytes(number: int, payload: bytes) -> bytes:
    return _pb_varint(number << 3 | 2) + _pb_varint(len(payload)) + payload


def _pb_uint(number: int, value: int) -> bytes:
    return _pb_varint(number << 3) + _pb_varint(value)


class _RawBytes:
    """A blob cell; the CLI prints it as "<raw bytes>"."""

    def __repr__(self) -> str:
        return "<raw bytes>"


_RAW_BYTES = _RawBytes()


def _rpc_cells(batches: list[bytes], check: Callable[[], None] = lambda: None) -> list[object]:
    """Decode QueryResult.CellsBatch messages into a flat cell list."""
    cells: list[object] = []
    for batch in batches:
        check()
        types: list[int] = []
        varints: list[int] = []
        doubles: list[float] = []
        blobs: list[bytes] = []
        strings: list[str] = []
        for number, wire, value in _pb_typed_fields(batch, _BATCH_WIRES):
            if number == 1:
                types.extend(_pb_packed_varints(value, wire))
            elif number == 2:
                varints.extend(_pb_packed_varints(value, wire))
            elif number == 3:
                if len(value) % 8:
                    raise _malformed("float64 cells are not whole doubles")
                doubles.extend(struct.unpack(f"<{len(value) // 8}d", value))
            elif number == 4:
                blobs.append(value)
            elif number == 5:
                text = value.decode("utf-8", errors="replace")
                if text and not text.endswith("\0"):
                    raise _malformed("string cells are not NUL-terminated")
                strings.extend(text.split("\0")[:-1])
        sources = {2: iter(varints), 3: iter(doubles), 4: iter(strings), 5: iter(blobs)}
        try:
            for cell_type in types:
                if cell_type == 1:
                    cells.append(None)
                elif cell_type == 2:
                    number = next(sources[2])
                    cells.append(number - (1 << 64) if number >= 1 << 63 else number)
                elif cell_type in (3, 4):
                    cells.append(next(sources[cell_type]))
                elif cell_type == 5:
                    next(sources[5])
                    cells.append(_RAW_BYTES)
                else:
                    raise _malformed(f"cell type {cell_type}")
        except StopIteration as error:
            raise _malformed("a cell has no value") from error
        if any(next(source, None) is not None for source in sources.values()):
            raise _malformed("a value has no cell")
    return cells


def _row_value(value: object) -> str | int | float | None:
    """The portable value of one cell.

    Text holding a plain decimal number reads as that number, as the CSV path
    always did: Skills print 64-bit timestamps with printf('%d') so that
    SmartPerfetto's JavaScript keeps them exact, and JavaScript coerces such
    text in comparisons, arithmetic and bare SQL placeholders where this
    runtime's evaluator does not. Unlike the CSV path, NULL stays distinct
    from the text "[NULL]", and text never changes shape.
    """
    if value is _RAW_BYTES:
        return "<raw bytes>"
    if isinstance(value, str):
        if _INTEGER.fullmatch(value):
            return int(value)
        if _FLOAT.fullmatch(value):
            return float(value)
    return value  # type: ignore[return-value]


def _csv_cell(value: object) -> str:
    # The CLI's CSV shape, with two deliberate differences: doubles keep full
    # precision (the shortest text that round-trips), and quotes inside a
    # string are doubled, so the output is valid CSV.
    if value is None:
        return '"[NULL]"'
    if value is _RAW_BYTES:
        return '"<raw bytes>"'
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, int):
        return str(value)
    return '"' + str(value).replace('"', '""') + '"'


@dataclass(frozen=True)
class _ResultSet:
    columns: tuple[str, ...]
    rows: tuple[tuple[object, ...], ...]

    def csv_lines(self) -> Iterator[str]:
        yield ",".join('"' + name.replace('"', '""') + '"' for name in self.columns) + "\n"
        for row in self.rows:
            yield ",".join(_csv_cell(value) for value in row) + "\n"


class _TraceProcessorRpc:
    """A `trace_processor_shell server stdio TRACE` child and its RPC stream."""

    def __init__(self, binary: Path, trace: Path) -> None:
        self.command = (str(binary), "server", "--extra-checks", "stdio", str(trace))
        self._process = subprocess.Popen(
            (sys.executable, "-c", _RPC_GUARDIAN, str(os.getpid()), *self.command),
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
        )
        self._reaped = False
        self._signalled = False
        try:
            self._start()
        except BaseException:
            self.kill()
            raise

    def _start(self) -> None:
        self._chunks: queue.Queue[bytes | None] = queue.Queue(maxsize=_RPC_QUEUED_CHUNKS)
        self._requests: queue.Queue[bytes | None] = queue.Queue()
        self._buffer = bytearray()
        self._stderr_tail = bytearray()
        self._stderr_bytes = 0
        self._stderr_base = 0
        self._received = 0
        self._seq = 0
        self.requests_written = 0
        self.answered = False
        self._threads: tuple[threading.Thread, ...] = ()
        threads = (
            threading.Thread(target=self._read, daemon=True),
            threading.Thread(target=self._write, daemon=True),
            threading.Thread(target=self._drain_stderr, daemon=True),
        )
        for thread in threads:
            thread.start()
            self._threads += (thread,)

    def _read(self) -> None:
        stdout = self._process.stdout
        assert stdout is not None
        try:
            while chunk := stdout.read1(_RPC_READ_CHUNK):
                self._chunks.put(chunk)
        except (OSError, ValueError):
            pass
        self._chunks.put(None)

    def _write(self) -> None:
        stdin = self._process.stdin
        assert stdin is not None
        try:
            while (request := self._requests.get()) is not None:
                stdin.write(request)
                stdin.flush()
                self.requests_written += 1
        except (OSError, ValueError):
            pass
        finally:
            try:
                stdin.close()
            except OSError:
                pass

    def _drain_stderr(self) -> None:
        stderr = self._process.stderr
        assert stderr is not None
        try:
            while chunk := stderr.read1(_RPC_READ_CHUNK):
                self._stderr_bytes += len(chunk)
                self._stderr_tail.extend(chunk)
                del self._stderr_tail[:-_STDERR_TAIL]
        except (OSError, ValueError):
            pass

    def begin_query(self) -> None:
        """Start one query's output budget, shared by every exchange it needs."""
        self._received = 0
        self._stderr_base = self._stderr_bytes

    def stderr_tail(self) -> str:
        return bytes(self._stderr_tail).decode("utf-8", errors="replace").strip()

    def _check(self, limits: _ProcessorLimits) -> None:
        if time.monotonic() >= limits.deadline:
            self.kill()
            raise limits.timed_out()
        if self._received > limits.max_output_bytes or self._stderr_bytes - self._stderr_base > limits.max_output_bytes:
            self.kill()
            raise limits.over_limit()

    def _message(self, limits: _ProcessorLimits) -> bytes:
        """Next TraceProcessorRpc message (each is field 1 of the stream)."""
        while True:
            self._check(limits)
            if self._buffer:
                if self._buffer[0] != 0x0A:
                    if not self.answered:
                        # Whatever this binary prints, it does not serve RPC on stdio.
                        self.kill()
                        raise _RpcUnavailable("not a TraceProcessorRpcStream")
                    raise _malformed("stream item is not TraceProcessorRpcStream.msg")
                try:
                    length, index = _pb_read_varint(self._buffer, 1)
                except IndexError:
                    length, index = -1, 0
                if length >= 0 and len(self._buffer) >= index + length:
                    message = bytes(self._buffer[index:index + length])
                    del self._buffer[:index + length]
                    return message
            # Short waits keep the stderr budget enforced while stdout is quiet.
            remaining = limits.deadline - time.monotonic()
            try:
                chunk = self._chunks.get(timeout=min(max(remaining, 0.0), 0.05))
            except queue.Empty:
                continue
            if chunk is None:
                # Stdout closed: the process should be exiting, but the deadline
                # and the stderr budget still hold while it does.
                while not self._exited():
                    self._check(limits)
                    time.sleep(0.02)
                detail = self.stderr_tail()
                if not self.answered:
                    raise _RpcUnavailable(detail)
                raise QueryError(f"trace_processor_shell exited during a query: {detail}")
            self._received += len(chunk)
            self._buffer.extend(chunk)

    def _statement(self, sql: bytes, offset: int, limits: _ProcessorLimits) -> tuple[_ResultSet, bool, int, int, str | None]:
        """Run the next statement: (result, executed, tail offset, output count, error)."""
        self._seq += 1
        args = _pb_bytes(1, sql) + _pb_uint(2, offset)
        request = _pb_uint(1, self._seq) + _pb_uint(2, _TPM_STATEMENT_STREAMING) + _pb_bytes(115, args)
        self._requests.put(_pb_bytes(1, request))
        columns: list[str] = []
        batches: list[bytes] = []
        executed, tail, with_output, error = False, offset, 0, None
        while True:
            message = self._message(limits)
            statement: bytes | None = None
            for number, _wire, value in _pb_typed_fields(message, _RPC_WIRES):
                if number == 4:
                    raise _RpcUnavailable("statement streaming is not supported")
                if number == 5:
                    raise QueryError(f"trace_processor_shell RPC failed: {value.decode('utf-8', 'replace')}")
                if number == 219:
                    statement = value
            if statement is None:
                continue
            self.answered = True
            last = False
            for number, _wire, value in _pb_typed_fields(statement, _STATEMENT_WIRES):
                if number == 2:
                    tail = value
                elif number == 3:
                    executed = bool(value)
                elif number == 1:
                    for field_number, _field_wire, item in _pb_typed_fields(value, _RESULT_WIRES):
                        if field_number == 1:
                            columns.append(item.decode("utf-8", "replace"))
                        elif field_number == 2:
                            error = item.decode("utf-8", "replace")
                        elif field_number == 3:
                            batches.append(item)
                            last = last or any(
                                number == 6 and bool(flag) for number, _w, flag in _pb_typed_fields(item, _BATCH_WIRES)
                            )
                        elif field_number == 5:
                            with_output = item
            if last:
                break
        cells = _rpc_cells(batches, lambda: self._check(limits))
        width = len(columns)
        if (width and len(cells) % width) or (not width and cells):
            raise _malformed("cells do not fill whole rows")
        rows = tuple(tuple(cells[index:index + width]) for index in range(0, len(cells), width)) if width else ()
        self._check(limits)
        return _ResultSet(tuple(columns), rows), executed, tail, with_output, error

    def run(self, sql: str, limits: _ProcessorLimits) -> QueryResult:
        """Run every statement of `sql` and print them as the CLI does."""
        encoded = sql.encode("utf-8")
        offset = 0
        printed: list[_ResultSet] = []
        executed_any = False
        error: str | None = None
        lines: list[str] = []
        size = 0
        while True:
            result, executed, offset, with_output, error = self._statement(encoded, offset, limits)
            if error is not None or not executed:
                break
            executed_any = True
            # The CLI prints nothing for a statement without columns, for rows
            # it counts as having no output, and for an empty
            # `suppress_query_output` result.
            if not result.columns or (result.rows and not with_output) or (
                not result.rows and result.columns == ("suppress_query_output",)
            ):
                continue
            if printed:
                lines.append("\n")
                size += 1
            printed.append(result)
            for index, line in enumerate(result.csv_lines()):
                size += len(line.encode("utf-8"))
                if size > limits.max_output_bytes:
                    self.kill()
                    raise limits.over_limit()
                if index % 1024 == 0:
                    self._check(limits)
                lines.append(line)
        if error is None and not executed_any:
            error = "No valid SQL to run"
        if error is not None and len(error.encode("utf-8")) > limits.max_output_bytes:
            raise limits.over_limit()
        rows = None
        # Typed rows exist for exactly one printed result set; several result
        # sets keep the CLI's layout and are read from the CSV.
        if error is None and len(printed) == 1:
            columns = printed[0].columns
            converted: list[dict[str, str | int | float | None]] = []
            for index, row in enumerate(printed[0].rows):
                if index % 1024 == 0:
                    self._check(limits)
                converted.append({name: _row_value(value) for name, value in zip(columns, row)})
            rows = tuple(converted)
        stdout = "".join(lines)
        # Nothing returns as a success once its deadline has passed.
        self._check(limits)
        return QueryResult(
            stdout=stdout,
            stderr=error or "",
            returncode=1 if error is not None else 0,
            command=self.command,
            rows=rows,
        )

    def _exited(self) -> bool:
        """Whether the processor has exited, judged without reaping anything.

        Only the processor holds its stderr pipe (the guardian closes its
        copies at once), so that pipe's end marks the processor's exit.
        """
        return self._reaped or len(self._threads) < 3 or not self._threads[2].is_alive()

    def close(self) -> None:
        """Close stdin (the server then exits) and release every pipe."""
        if not self._reaped and hasattr(self, "_requests"):
            self._requests.put(None)
            deadline = time.monotonic() + 3
            while not self._exited() and time.monotonic() < deadline:
                time.sleep(0.02)
        self.kill()

    def kill(self) -> None:
        if self._reaped:
            return
        # Only this method reaps the guardian, and only after signalling its
        # group: until then the zombie guardian keeps the group ID reserved,
        # so the signal can reach no process but the guardian and its child.
        # The group is signalled at most once: an interrupted wait may already
        # have reaped the guardian, and a retry must not signal a freed ID.
        if not self._signalled:
            self._signalled = True
            try:
                os.killpg(self._process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        self._process.wait()
        self._reaped = True
        if hasattr(self, "_requests"):
            self._requests.put(None)
            self._release()
        else:
            for stream in (self._process.stdin, self._process.stdout, self._process.stderr):
                if stream is not None:
                    stream.close()

    def _release(self) -> None:
        if not self._threads:
            for stream in (self._process.stdin, self._process.stdout, self._process.stderr):
                if stream is not None:
                    stream.close()
            return
        reader = self._threads[0]
        deadline = time.monotonic() + 3
        while reader.is_alive() and time.monotonic() < deadline:
            # Unblock a reader waiting on the bounded queue so it can see EOF.
            try:
                while True:
                    self._chunks.get_nowait()
            except queue.Empty:
                pass
            reader.join(timeout=0.02)
        for thread in self._threads[1:]:
            thread.join(timeout=1)
        for stream in (self._process.stdin, self._process.stdout, self._process.stderr):
            if stream is not None:
                try:
                    stream.close()
                except OSError:
                    pass


def _run_rpc_once(binary: Path, trace: Path, sql: str, limits: _ProcessorLimits) -> QueryResult | None:
    """One-shot query over RPC; None when the processor has no stdio RPC."""
    rpc = _TraceProcessorRpc(binary, trace)
    try:
        rpc.begin_query()
        return rpc.run(sql, limits)
    except _RpcUnavailable:
        _RPC_UNAVAILABLE.add((binary, trace))
        return None
    finally:
        rpc.kill()


# A warm session must answer every query exactly as a fresh process would.
# Body statements run inside BEGIN/ROLLBACK, which SQLite undoes for tables,
# views and indexes (PERFETTO ones included), but not for PERFETTO FUNCTION or
# MACRO definitions, metric/IMPORT side effects, or module includes: a rolled
# back INCLUDE stays marked as loaded while its tables disappear. Includes are
# therefore run before the transaction and accumulate, and a query is admitted
# only when it includes every module the session already loaded, so it sees
# exactly the schema its own includes produce. Anything else runs one-shot.
_SESSION_INCLUDE = re.compile(
    r"INCLUDE\s+PERFETTO\s+MODULE\s+([A-Za-z_][A-Za-z0-9_.]*)", re.IGNORECASE
)
_SESSION_BODY = re.compile(
    r"(?:SELECT|WITH|VALUES"
    r"|CREATE\s+(?:OR\s+REPLACE\s+)?PERFETTO\s+(?:TABLE|VIEW|INDEX)"
    r"|CREATE\s+(?:TEMP(?:ORARY)?\s+)?(?:TABLE|VIEW))\b",
    re.IGNORECASE,
)
_SESSION_UNSAFE_CALL = re.compile(r"\b(?:RUN_METRIC|IMPORT)\s*\(", re.IGNORECASE)


@dataclass(frozen=True)
class _SessionPlan:
    includes: str
    body: str
    modules: frozenset[str]


def _sql_statements(sql: str) -> list[tuple[int, str]] | None:
    """Split SQL into (end offset, code without comments or literals).

    None when the text ends inside a literal or comment: the appended ROLLBACK
    would be swallowed and leave the session inside a transaction.
    """
    statements: list[tuple[int, str]] = []
    code: list[str] = []
    quote = ""
    comment = ""
    index = 0
    while index < len(sql):
        current = sql[index]
        following = sql[index + 1] if index + 1 < len(sql) else ""
        if comment == "line":
            if current == "\n":
                comment = ""
        elif comment == "block":
            if current == "*" and following == "/":
                comment = ""
                index += 1
        elif quote:
            if current == quote:
                if following == quote and quote != "]":
                    index += 1
                else:
                    quote = ""
        elif current == "-" and following == "-":
            comment = "line"
            code.append(" ")
            index += 1
        elif current == "/" and following == "*":
            comment = "block"
            code.append(" ")
            index += 1
        elif current in ("'", '"', "`", "["):
            quote = "]" if current == "[" else current
            code.append(" ? ")
        else:
            code.append(current)
            if current == ";":
                statements.append((index + 1, "".join(code)))
                code = []
        index += 1
    if quote or comment == "block":
        return None
    statements.append((len(sql), "".join(code)))
    return statements


def _session_plan(sql: str) -> _SessionPlan | None:
    statements = _sql_statements(sql)
    if statements is None:
        return None
    modules: set[str] = set()
    includes_end = 0
    has_body = False
    for end, code in statements:
        statement = code.strip().rstrip(";").strip()
        if not statement:
            continue
        include = _SESSION_INCLUDE.fullmatch(statement)
        if include is not None and not has_body:
            modules.add(include.group(1))
            includes_end = end
        elif include is None and _SESSION_BODY.match(statement) and not _SESSION_UNSAFE_CALL.search(statement):
            has_body = True
        else:
            return None
    if not has_body:
        return None
    return _SessionPlan(sql[:includes_end], sql[includes_end:], frozenset(modules))


class TraceProcessorSession:
    """One loaded trace that run_query reuses for statements a rollback undoes."""

    def __init__(self, trace: Path, binary: Path) -> None:
        self.trace = trace
        self.binary = binary
        self.start_count = 0
        self.unavailable = not _RPC_SUPPORTED or (binary, trace) in _RPC_UNAVAILABLE
        self.modules: frozenset[str] = frozenset()
        self._rpc: _TraceProcessorRpc | None = None
        self._lock = threading.Lock()

    def run(self, plan: _SessionPlan, limits: _ProcessorLimits) -> QueryResult | None:
        """Return the query result, or None when the caller must run it one-shot."""
        with self._lock:
            if self._rpc is not None and not self.modules <= plan.modules:
                self.close()
            fresh = self._rpc is None
            if fresh:
                self._rpc = _TraceProcessorRpc(self.binary, self.trace)
            try:
                self._rpc.begin_query()
                # The includes keep their own positions, and the body keeps
                # its line and column numbers behind a blank of the includes,
                # so error locations match a one-shot run.
                begin = self._rpc.run(plan.includes + "\nBEGIN;\n", limits)
                if fresh:
                    self.start_count += 1
                if begin.returncode != 0:
                    self.close()
                    return begin
                self.modules |= plan.modules
                blank = re.sub(r"[^\n]", " ", plan.includes)
                result = self._rpc.run(f"{blank}{plan.body}\n;\nROLLBACK;\n", limits)
                # A failing body statement stops before the ROLLBACK, and
                # every admitted body statement is undone by one.
                if result.returncode != 0 and self._rpc.run("ROLLBACK;", limits).returncode != 0:
                    self.close()
                return result
            except _RpcUnavailable:
                # No stdio RPC, or a trace it cannot load: the CLI reports the
                # processor's own result for every later query.
                _RPC_UNAVAILABLE.add((self.binary, self.trace))
                self.unavailable = True
                self.close()
                return None
            except BaseException:
                self.close()
                raise

    def close(self) -> None:
        if self._rpc is not None:
            self._rpc.kill()
            self._rpc = None
        self.modules = frozenset()


_trace_sessions: ContextVar[tuple[TraceProcessorSession, ...]] = ContextVar(
    "perfetto_trace_sessions", default=()
)


def _active_session(trace: Path, binary: Path) -> TraceProcessorSession | None:
    return next(
        (item for item in _trace_sessions.get() if item.trace == trace and item.binary == binary),
        None,
    )


@contextmanager
def trace_processor_session(
    trace: str | Path, *, trace_processor: str | None = None
) -> Iterator[TraceProcessorSession]:
    """Keep `trace` loaded for run_query calls in this context.

    Re-entering for the same trace and processor yields the active session;
    queries for any other trace still run one-shot.
    """
    resolved = Path(trace).expanduser().resolve()
    binary = resolve_trace_processor(trace_processor)
    active = _active_session(resolved, binary)
    if active is not None:
        yield active
        return
    session = TraceProcessorSession(resolved, binary)
    token = _trace_sessions.set(_trace_sessions.get() + (session,))
    try:
        yield session
    finally:
        _trace_sessions.reset(token)
        session.close()


def include_modules_sql(modules: Iterable[str]) -> str:
    return "\n".join(f"INCLUDE PERFETTO MODULE {module};" for module in modules)


def table_access_sql(tables: Iterable[str]) -> str:
    return "\n".join(f"SELECT * FROM {quote_identifier(table)} LIMIT 0;" for table in tables)


T = TypeVar("T")
R = TypeVar("R")


def run_batch_or_each(items: Sequence[T], attempt: Callable[[Sequence[T]], R]) -> tuple[list[R], list[T]]:
    """Run `attempt` on all items at once, splitting only when the batch fails.

    Outside a warm session every invocation re-parses the whole trace, so the
    common all-readable case costs one invocation; a failed batch is retried
    per item to name the failures. Returns (results, failed items).
    """
    try:
        return [attempt(items)], []
    except RuntimeError:
        pass
    results: list[R] = []
    failed: list[T] = []
    for item in items:
        try:
            results.append(attempt([item]))
        except RuntimeError:
            failed.append(item)
    return results, failed


def missing_tables(
    trace_path: str | Path,
    tables: Sequence[str],
    *,
    modules: Iterable[str] = (),
    trace_processor: str | None = None,
    timeout: float = 120.0,
    max_output_bytes: int = DEFAULT_MAX_OUTPUT_BYTES,
) -> list[str]:
    """Return the tables the trace cannot read after including `modules`."""
    if not tables:
        return []
    includes = include_modules_sql(modules)
    _results, missing = run_batch_or_each(
        tables,
        lambda batch: run_query(
            trace_path,
            sql=f"{includes}\n{table_access_sql(batch)}",
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        ),
    )
    return missing


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


def _sql_string_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float, str)):
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("SQL parameters cannot contain NaN or infinity")
        return str(value)
    if isinstance(value, (list, tuple)):
        return ",".join(_sql_string_text(item) for item in value)
    raise ValueError(f"unsupported SQL string parameter type: {type(value).__name__}")


def sql_string_fragment(value: object, literal: _SqlToken | None = None, name: str = "value") -> str:
    """A value's text inside a single-quoted literal; in a GLOB/LIKE pattern
    literal its own wildcards are escaped before quotes are doubled."""
    text = _sql_string_text(value)
    if literal is not None:
        text = _sql_pattern_text(text, literal, name)
    return text.replace("'", "''")


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


_RESULT_STEP = re.compile(r"\.([A-Za-z_][A-Za-z0-9_]*)|\[(0|[1-9][0-9]*)\]")
_RESULT_PATH = re.compile(rf"(?:{_RESULT_STEP.pattern})*")


def resolve_result_expression(
    expression: str, results: Mapping[str, object], *, allow_missing: bool = False
) -> tuple[bool, bool, object]:
    """Resolve a pipeline-style result path.

    Returns ``(matched, is_relation, value)``. A bare result name denotes the
    complete row relation; dotted fields and numeric indexes select a scalar.
    ``data`` and ``rows`` are accepted as aliases for a top-level row array so
    exported SmartPerfetto expressions keep their documented shape. With
    ``allow_missing`` an index past the end (``data[0]`` of an empty result)
    or a null value along the path resolves to None; a missing field or a
    non-array index is still an error.
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
        # A null saved result is bound (it shadows a same-name input) but holds
        # no rows, so it reads as a scalar null.
        return True, results[root] is not None, results[root]

    if not _RESULT_PATH.fullmatch(expression, len(root)):
        raise ValueError(f"invalid saved result path: {expression!r}")
    value = results[root]
    for field, index in _RESULT_STEP.findall(expression, len(root)):
        if allow_missing and value is None:
            return True, False, None
        if index:
            if not isinstance(value, list):
                raise ValueError(
                    f"saved result path {expression!r} indexes a non-array value"
                )
            if int(index) < len(value):
                value = value[int(index)]
            elif allow_missing:
                return True, False, None
            else:
                raise ValueError(
                    f"saved result path {expression!r} index {index} is out of range"
                )
        elif isinstance(value, list) and field in {"data", "rows"}:
            pass
        elif isinstance(value, dict) and field in value:
            value = value[field]
        elif isinstance(value, dict) and field == "data" and "rows" in value:
            value = value["rows"]
        else:
            raise ValueError(
                f"saved result path {expression!r} has no field {field!r}"
            )
    if isinstance(value, (dict, list, tuple)):
        raise ValueError(f"saved result path {expression!r} does not resolve to a scalar")
    return True, False, value


def sql_template_roots(
    template: str, result_names: Iterable[str]
) -> tuple[list[str], list[str], list[str]]:
    """Split the variables a template renders into parameters, the saved
    results it reads, and the dependencies among those it cannot render
    without rows.

    A bare relation always needs rows. A path with `|default` renders the
    default when the result is unbound or has fewer rows than it indexes, so
    only a path without one is a dependency. Comments are never rendered and
    do not count.
    """
    names = set(result_names)
    parameters: set[str] = set()
    references: set[str] = set()
    dependencies: set[str] = set()
    for expression in sql_template_expressions(template):
        name, separator, _default = expression.partition("|")
        root = template_root(name)
        if root == "__process_scope":
            continue
        if root not in names:
            parameters.add(root)
            continue
        references.add(root)
        if name == root or not separator:
            dependencies.add(root)
    return sorted(parameters), sorted(references), sorted(dependencies)


_SQL_PLACEHOLDER = re.compile(r"\$\{([^}]+)\}")
_SQL_WORD = re.compile(r"(?:[\w.]|\$(?!\{))+", re.ASCII)
_SQL_OPERATOR = re.compile(r"[=<>!]+|\|+|.", re.DOTALL)
_SQL_COMPARISON = re.compile(r"[=<>!]+")
# SQLite's identifier quotes and the character that closes each.
_SQL_IDENTIFIER_CLOSE = {'"': '"', "`": "`", "[": "]"}
_SQL_PATTERN_OPERATORS = frozenset({"GLOB", "LIKE", "REGEXP", "MATCH"})
# Words that end a pattern operand at its own nesting depth.
_SQL_OPERAND_END_WORDS = frozenset({
    "AND", "OR", "NOT", "IS", "IN", "BETWEEN", "ESCAPE", "THEN", "WHEN", "ELSE", "END",
    "FROM", "WHERE", "GROUP", "HAVING", "WINDOW", "ORDER", "LIMIT", "UNION", "EXCEPT", "INTERSECT",
    "AS", "ON", "JOIN",
})


@dataclass
class _SqlToken:
    kind: str  # "word", "identifier", "string" or "punct"
    text: str = ""  # upper-cased word or quoted name, the punctuation, or the decoded literal text
    pattern: str | None = None  # "glob" or "like": this literal is the whole pattern
    escape: str | None = None  # the LIKE ESCAPE character, when exactly one
    in_pattern_expression: bool = False  # in a pattern operand, not as its only literal
    bound: bool = False  # a string literal with a placeholder in it


@dataclass
class SqlPlaceholderPlace:
    """Where one `${...}` sits in SQL text (SmartPerfetto sqlTemplate.ts)."""

    context: str  # "code", "string", "comment", "identifier" or "malformed"
    match: str
    token: _SqlToken | None = None  # the code token or string literal holding it
    literal_prefix: str = ""  # in a string literal: the author's text before it


def sql_placeholder_places(template: str) -> dict[int, SqlPlaceholderPlace]:
    """Every placeholder start, in order, with where it sits. Placeholders are
    opaque: a quote or comment marker inside `${...}` is not SQL. A `${` that
    is not a placeholder outside comments is "malformed". SmartPerfetto's
    sqlTemplate.ts scans with the same tokens and operand rules."""
    at = {m.start(): m.group(0) for m in _SQL_PLACEHOLDER.finditer(template)}
    places: dict[int, SqlPlaceholderPlace] = {}
    tokens: list[_SqlToken] = []

    def record(index: int, context: str, token: _SqlToken | None = None) -> int:
        prefix = ""
        if context == "string" and token is not None:
            token.bound = True
            prefix = token.text
        places[index] = SqlPlaceholderPlace(context, at[index], token, prefix)
        return index + len(at[index])

    def malformed(index: int) -> bool:
        if template.startswith("${", index):
            places[index] = SqlPlaceholderPlace("malformed", "${")
            return True
        return False

    def quoted(index: int, close: str, context: str, token: _SqlToken | None = None) -> int:
        while index < len(template):
            if index in at:
                index = record(index, context, token)
                continue
            if malformed(index):
                index += 2
                continue
            if template[index] == close:
                if close == "]" or template[index + 1:index + 2] != close:
                    return index + 1
                if token is not None:
                    token.text += close
                index += 2
                continue
            if token is not None:
                token.text += template[index]
            index += 1
        return index

    index = 0
    while index < len(template):
        char = template[index]
        if index in at:
            token = _SqlToken("word")
            tokens.append(token)
            index = record(index, "code", token)
        elif malformed(index):
            index += 2
        elif char.isspace():
            index += 1
        elif template.startswith("--", index) or template.startswith("/*", index):
            close = "\n" if char == "-" else "*/"
            found = template.find(close, index + 2)
            end = len(template) if found < 0 else found + len(close)
            index += 2
            while index < end:
                index = record(index, "comment") if index in at else index + 1
        elif char == "'":
            token = _SqlToken("string")
            tokens.append(token)
            index = quoted(index + 1, "'", "string", token)
        elif char in _SQL_IDENTIFIER_CLOSE:
            # A quoted name is never a keyword, but `"glob"(...)` still calls GLOB.
            token = _SqlToken("identifier")
            tokens.append(token)
            index = quoted(index + 1, _SQL_IDENTIFIER_CLOSE[char], "identifier", token)
            token.text = token.text.upper()
        else:
            word = _SQL_WORD.match(template, index)
            if word:
                tokens.append(_SqlToken("word", word.group(0).upper()))
                index = word.end()
            else:
                op = _SQL_OPERATOR.match(template, index)
                tokens.append(_SqlToken("punct", op.group(0)))
                index = op.end()
    _mark_sql_pattern_operands(tokens)
    return places


def _is_sql_punct(token: _SqlToken | None, text: str) -> bool:
    return token is not None and token.kind == "punct" and token.text == text


def _is_sql_word(token: _SqlToken | None, text: str) -> bool:
    return token is not None and token.kind == "word" and token.text == text


def _sql_operand_end(tokens: list[_SqlToken], start: int) -> int:
    """The index just past the expression at `start`; CASE ... END nests like parentheses."""
    end = start
    depth = 0
    while end < len(tokens):
        t = tokens[end]
        if _is_sql_punct(t, "(") or _is_sql_word(t, "CASE"):
            depth += 1
        elif _is_sql_punct(t, ")") or _is_sql_word(t, "END"):
            if depth == 0:
                break
            depth -= 1
        elif depth == 0 and t.kind == "punct" and (t.text in {",", ";"} or _SQL_COMPARISON.fullmatch(t.text)):
            break
        elif depth == 0 and t.kind == "word" and t.text in _SQL_OPERAND_END_WORDS:
            break
        end += 1
    return end


def _sql_sole_token(tokens: list[_SqlToken], first: int, last: int) -> _SqlToken | None:
    """The one token `first..last` amounts to, through wrapping parentheses and postfix COLLATE."""
    while True:
        if last - first >= 2 and _is_sql_word(tokens[last - 1], "COLLATE"):
            last -= 2
        elif (
            last > first and _is_sql_punct(tokens[first], "(") and _is_sql_punct(tokens[last], ")")
            and _sql_closes(tokens, first, last)
        ):
            first += 1
            last -= 1
        else:
            return tokens[first] if first == last else None


def _mark_sql_pattern_operands(tokens: list[_SqlToken]) -> None:
    """Tag the tokens of each GLOB/LIKE/REGEXP/MATCH right operand. Only a
    string literal that is the whole GLOB/LIKE pattern, with no ESCAPE or a
    fixed one-character ESCAPE literal, can take a value."""
    for k, token in enumerate(tokens):
        operator = token.text in _SQL_PATTERN_OPERATORS and (
            token.kind == "word"
            or (token.kind == "identifier" and k + 1 < len(tokens) and _is_sql_punct(tokens[k + 1], "("))
        )
        if not operator:
            continue
        end = _sql_operand_end(tokens, k + 1)
        escape: str | None = None
        escape_fixed = True
        if end < len(tokens) and _is_sql_word(tokens[end], "ESCAPE"):
            escape_end = _sql_operand_end(tokens, end + 1)
            literal = _sql_sole_token(tokens, end + 1, escape_end - 1) if escape_end > end + 1 else None
            escape_fixed = (
                token.text == "LIKE" and literal is not None and literal.kind == "string"
                and not literal.bound and len(literal.text) == 1
            )
            if escape_fixed:
                escape = literal.text
            for t in range(end + 1, escape_end):
                tokens[t].in_pattern_expression = True
        pattern = _sql_sole_token(tokens, k + 1, end - 1) if end > k + 1 else None
        if escape_fixed and pattern is not None and pattern.kind == "string" and token.text in {"GLOB", "LIKE"}:
            pattern.pattern = token.text.lower()
            pattern.escape = escape
        else:
            for t in range(k + 1, end):
                tokens[t].in_pattern_expression = True


def _inside_glob_class(text: str) -> bool:
    """Whether a GLOB pattern's author text leaves the next character inside a `[...]` class."""
    open_index = -1
    for i, char in enumerate(text):
        if open_index < 0:
            if char == "[":
                open_index = i
        elif char == "]" and i > open_index + (2 if text[open_index + 1:open_index + 2] == "^" else 1):
            open_index = -1
    return open_index >= 0


def _ends_escaping(text: str, escape: str) -> bool:
    """Whether `text` ends in an odd run of `escape`, which escapes the next character."""
    return (len(text) - len(text.rstrip(escape))) % 2 == 1


def _sql_closes(tokens: list[_SqlToken], open_index: int, close_index: int) -> bool:
    depth = 0
    for t in range(open_index, close_index + 1):
        if _is_sql_punct(tokens[t], "("):
            depth += 1
        elif _is_sql_punct(tokens[t], ")"):
            depth -= 1
            if depth == 0:
                return t == close_index
    return False


def _sql_pattern_text(text: str, token: _SqlToken, name: str) -> str:
    """A bound value's text in a pattern literal: its own wildcards match
    themselves, each character mapped once. LIKE without ESCAPE cannot escape,
    so `%` or `_` is refused."""
    if token.pattern == "glob":
        return re.sub(r"[*?\[]", lambda m: f"[{m.group(0)}]", text)
    if token.pattern == "like":
        if token.escape:
            return "".join(token.escape + ch if ch in {"%", "_", token.escape} else ch for ch in text)
        if "%" in text or "_" in text:
            raise ValueError(f"SQL placeholder {name!r} binds a LIKE pattern without ESCAPE; its value cannot contain % or _")
    return text


def render_sql_template(
    template: str,
    parameters: Mapping[str, object],
    results: Mapping[str, object],
    *,
    process_scope: RuntimeProcessScope | None = None,
    trace_sha256: str | None = None,
    trace_side: str | None = None,
) -> str:
    reject_process_scope_names(parameters)
    reject_process_scope_names(results)
    output: list[str] = []
    template_names: set[str] | None = None
    cursor = 0
    for index, place in sql_placeholder_places(template).items():
        if place.context == "comment":
            continue
        if place.context == "malformed":
            if template.find("}", index + 2) < 0:
                raise ValueError("unterminated SQL template placeholder")
            raise ValueError("empty SQL template placeholder")
        end = index + len(place.match)
        name, separator, raw_default = place.match[2:-1].partition("|")
        if not name:
            raise ValueError("empty SQL template placeholder")
        if place.context == "identifier":
            raise ValueError(f"SQL placeholder {name!r} cannot be bound inside a quoted identifier")
        if place.token is not None and place.token.in_pattern_expression:
            raise ValueError(
                f"SQL placeholder {name!r} is part of a GLOB/LIKE/REGEXP/MATCH pattern expression; "
                "bind it as the pattern's only string literal, or compare with instr()"
            )
        in_string = place.context == "string"
        literal = place.token if in_string and place.token is not None and place.token.pattern else None
        if literal is not None and literal.pattern == "glob" and _inside_glob_class(place.literal_prefix):
            raise ValueError(f"SQL placeholder {name!r} sits inside a GLOB character class")
        if literal is not None and literal.escape and _ends_escaping(place.literal_prefix, literal.escape):
            raise ValueError(f"SQL placeholder {name!r} follows the pattern's ESCAPE character")
        output.append(template[cursor:index])
        cursor = end
        if is_process_scope_name(name):
            if name != "__process_scope.upid" or separator or in_string:
                raise ValueError("unsupported runtime process scope placeholder")
            if template_names is None:
                template_names = sql_template_names(template)
            output.append(sql_literal(_process_scope_value(
                process_scope, parameters, results, template_names, trace_sha256, trace_side,
            )))
            continue
        matched_result, is_relation, value = resolve_result_expression(
            name, results, allow_missing=bool(separator)
        )
        if not matched_result:
            if name not in parameters and not separator:
                raise ValueError(f"missing SQL template value: {name}")
            value = parameters.get(name)
        # SmartPerfetto: a bound name whose value is null (an unset optional
        # input, a null field, a row an empty result lacks) still takes its
        # `|default`, which is author text and keeps its own wildcards.
        from_default = value is None and bool(separator)
        if from_default:
            value = default_template_value(raw_default)
        if is_relation:
            if in_string:
                raise ValueError(
                    f"saved result {name!r} cannot be used inside a string"
                )
            output.append(result_rows_to_relation(value, name))
        elif in_string:
            output.append(sql_string_fragment(value, None if from_default else literal, name))
        else:
            text = sql_literal(value)
            # `1-${v}` with v = -1 must not become the comment `1--1`.
            output.append(f" {text}" if text.startswith("-") else text)
    output.append(template[cursor:])
    return "".join(output)

_INTEGER = re.compile(r"^-?(?:0|[1-9][0-9]*)$")
_FLOAT = re.compile(
    r"^-?(?:[0-9]+\.[0-9]*|[0-9]*\.[0-9]+|[0-9]+(?=[eE]))(?:[eE][+-]?[0-9]+)?$"
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
