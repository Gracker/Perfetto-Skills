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
import shutil
import subprocess
import tempfile
import threading
import time
import weakref
from collections.abc import Callable, Iterable, Iterator, Mapping, Sequence
from typing import Any, TypeVar


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
        if selector in supplied_parameters:
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
    if status == "resolved":
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


def resolve_identity(
    skill: Mapping[str, Any],
    params: Mapping[str, Any],
    *,
    trace: Path,
    trace_processor: str | None,
    timeout: float,
    max_output_bytes: int,
) -> dict[str, Any]:
    config = skill.get("identity", {}) or {"policy": "none"}
    policy = str(config.get("policy", "none"))
    if policy in {"none", "exempt"}:
        return {"status": "exempt", "policy": policy}
    aliases = [str(value) for value in config.get("aliases", [])]
    target_name = next(
        (str(params[name]) for name in aliases if params.get(name) not in (None, "")),
        None,
    )
    if target_name is None:
        return {"status": "not_requested", "policy": policy, "aliases": aliases}
    query = f"""
SELECT upid, pid, name, start_ts, end_ts
FROM process
WHERE name = {sql_literal(target_name)} OR name GLOB {sql_literal(target_name + ':*')}
ORDER BY CASE WHEN name = {sql_literal(target_name)} THEN 0 ELSE 1 END, start_ts;
""".strip()
    rows = parse_csv_output(
        run_query(
            trace,
            sql=query,
            trace_processor=trace_processor,
            timeout=timeout,
            max_output_bytes=max_output_bytes,
        ).stdout
    )
    exact = [row for row in rows if row.get("name") == target_name]
    candidates = exact or rows
    if len(candidates) == 1:
        candidate = candidates[0]
        return {
            "status": "resolved",
            "policy": policy,
            "target": target_name,
            "upid": candidate.get("upid"),
            "pid": candidate.get("pid"),
            "process_name": candidate.get("name"),
            "lifetime": {"start_ns": candidate.get("start_ts"), "end_ns": candidate.get("end_ts")},
        }
    return {
        "status": "not_found" if not candidates else "ambiguous",
        "policy": policy,
        "target": target_name,
        "candidates": candidates,
    }


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

    query_path: Path | None = None
    if sql_file is not None:
        query_path = Path(sql_file).expanduser().resolve()
        if not query_path.is_file():
            raise FileNotFoundError(f"SQL file not found: {query_path}")
    limits = _ProcessorLimits(time.monotonic() + timeout, timeout, max_output_bytes)
    result: QueryResult | None = None
    session = _active_session(trace, binary)
    if session is not None and not session.unavailable:
        try:
            plan = _session_plan(sql if query_path is None else query_path.read_text(encoding="utf-8"))
        except UnicodeDecodeError:
            plan = None
        if plan is not None:
            result = session.run(plan, limits)
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


def _run_processor(
    head: tuple[str, ...],
    tail: tuple[str, ...] = (),
    *,
    sql: str | None,
    sql_file: Path | None,
    limits: _ProcessorLimits,
) -> QueryResult:
    """Run `head --query-file SQL tail`; `sql` text goes through a temporary file."""
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
                        raise QueryError(
                            f"Trace query exceeded the {limits.max_output_bytes} byte output limit"
                        )
        if (
            stdout_path.stat().st_size > limits.max_output_bytes
            or stderr_path.stat().st_size > limits.max_output_bytes
        ):
            raise QueryError(
                f"Trace query exceeded the {limits.max_output_bytes} byte output limit"
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
    return QueryResult(stdout=stdout, stderr=stderr, returncode=returncode, command=command)


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

    # sockaddr_un.sun_path is 104 bytes on macOS and 108 on Linux.
    _MAX_SOCKET_PATH = 100

    def __init__(self, trace: Path, binary: Path) -> None:
        self.trace = trace
        self.binary = binary
        self.start_count = 0
        self.unavailable = os.name == "nt"
        self.modules: frozenset[str] = frozenset()
        self._process: subprocess.Popen[bytes] | None = None
        self._directory: Path | None = None
        self._lock = threading.Lock()

    @property
    def address(self) -> str:
        return str(self._directory / "trace.sock") if self._directory is not None else ""

    def run(self, plan: _SessionPlan, limits: _ProcessorLimits) -> QueryResult | None:
        """Return the query result, or None when the caller must run it one-shot."""
        with self._lock:
            if self._process is not None and (
                self._process.poll() is not None or not self.modules <= plan.modules
            ):
                self.close()
            if self._process is None and not self._start(limits):
                return None
            try:
                # The includes keep their own positions, and the body keeps
                # its line and column numbers behind a blank of the includes,
                # so error locations match a one-shot run.
                begin = self._remote(plan.includes + "\nBEGIN;\n", limits)
                if begin.returncode != 0:
                    self.close()
                    return begin
                self.modules |= plan.modules
                blank = re.sub(r"[^\n]", " ", plan.includes)
                result = self._remote(f"{blank}{plan.body}\n;\nROLLBACK;\n", limits)
                # A failing body statement stops before the ROLLBACK, and
                # every admitted body statement is undone by one.
                if result.returncode != 0 and self._remote("ROLLBACK;", limits).returncode != 0:
                    self.close()
                return result
            except BaseException:
                self.close()
                raise

    def _remote(self, sql: str, limits: _ProcessorLimits) -> QueryResult:
        return _run_processor(
            (str(self.binary), "query", "--remote", self.address), sql=sql, sql_file=None, limits=limits
        )

    def _start(self, limits: _ProcessorLimits) -> bool:
        if self.unavailable:
            return False
        self._directory = Path(tempfile.mkdtemp(prefix="perfetto-session-"))
        if len(os.fsencode(self.address)) > self._MAX_SOCKET_PATH:
            self.close()
            self.unavailable = True
            return False
        # The idle clock runs only once this process is gone, so a session
        # orphaned by a hard kill is reaped instead of holding the trace.
        self._process = subprocess.Popen(
            (
                str(self.binary), "server", "--extra-checks", "--idle-timeout", "60s",
                "--path", self.address, "unix", str(self.trace),
            ),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # The server creates its socket only after the trace has loaded.
        while not Path(self.address).exists():
            if self._process.poll() is not None:
                # No unix server mode, or a trace it cannot load: one-shot runs
                # report the processor's own result for every later query.
                self.close()
                self.unavailable = True
                return False
            if time.monotonic() >= limits.deadline:
                self.close()
                raise limits.timed_out()
            time.sleep(0.02)
        if self._remote("SELECT 1;", limits).returncode != 0:
            self.close()
            self.unavailable = True
            return False
        self.start_count += 1
        return True

    def close(self) -> None:
        if self._process is not None:
            if self._process.poll() is None:
                self._process.terminate()
                try:
                    self._process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self._process.kill()
                    self._process.wait()
            self._process = None
        if self._directory is not None:
            shutil.rmtree(self._directory, ignore_errors=True)
            self._directory = None
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
