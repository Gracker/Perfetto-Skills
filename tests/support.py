from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import subprocess
import sys
from types import ModuleType


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "perfetto-performance-analysis" / "scripts"
GENERATED_SQL = (
    ROOT
    / "skills"
    / "perfetto-performance-analysis"
    / "references"
    / "generated"
    / "sql"
)


def load_skill_script(name: str) -> ModuleType:
    path = SCRIPTS / f"{name}.py"
    if not path.is_file():
        raise FileNotFoundError(path)
    module_name = f"perfetto_skill_{name}"
    spec = spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise ImportError(path)
    module = module_from_spec(spec)
    sys.modules[module_name] = module
    sys.path.insert(0, str(SCRIPTS))
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path.remove(str(SCRIPTS))
    return module


def generated_sql(skill_name: str, filename: str) -> Path:
    path = GENERATED_SQL / skill_name / filename
    if not path.is_file():
        raise FileNotFoundError(path)
    return path


def trace_processor() -> str:
    executable = os.environ.get("PERFETTO_TRACE_PROCESSOR")
    if not executable:
        raise RuntimeError("PERFETTO_TRACE_PROCESSOR not configured")
    path = Path(executable).expanduser().resolve()
    if not path.is_file() or not os.access(path, os.X_OK):
        raise RuntimeError(f"trace processor is not executable: {path}")
    return str(path)


def run_json_command(command: list[str]) -> dict[str, object]:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        return {
            "status": "unavailable",
            "returncode": completed.returncode,
            "error": completed.stderr.strip() or completed.stdout.strip(),
        }
    try:
        parsed = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        return {"status": "unavailable", "error": f"invalid JSON output: {exc}"}
    if isinstance(parsed, dict):
        return {"status": "ok", **parsed}
    if isinstance(parsed, list):
        return {"status": "ok", "rows": parsed}
    return {"status": "unavailable", "error": "unexpected JSON result"}


def run_public_probe(trace: Path) -> dict[str, object]:
    return run_json_command(
        [
            sys.executable,
            str(SCRIPTS / "perfetto_probe.py"),
            str(trace),
            "--trace-processor",
            trace_processor(),
        ]
    )


def run_public_compare(
    sides: list[tuple[str, Path]], baseline: str
) -> dict[str, object]:
    command = [
        sys.executable,
        str(SCRIPTS / "perfetto_compare.py"),
        "--baseline",
        baseline,
    ]
    for label, path in sides:
        command.extend(("--side", f"{label}={path}"))
    return run_json_command(command)


def run_public_query(
    trace: Path,
    *,
    sql: str | None = None,
    sql_file: Path | None = None,
    modules: tuple[str, ...] = (),
    params: dict[str, object] | None = None,
) -> dict[str, object]:
    if (sql is None) == (sql_file is None):
        raise ValueError("provide exactly one of sql or sql_file")
    source_path: str | None = None
    if sql_file is not None:
        source_path = str(sql_file)
        sql = sql_file.read_text(encoding="utf-8")
    assert sql is not None
    command = [
            sys.executable,
            str(SCRIPTS / "perfetto_query.py"),
            str(trace),
            "--sql",
            sql,
            "--trace-processor",
            trace_processor(),
            "--format",
            "json",
        ]
    for module in modules:
        command.extend(("--module", module))
    for key, value in sorted((params or {}).items()):
        command.extend(("--param", f"{key}={json.dumps(value, ensure_ascii=False)}"))
    result = run_json_command(command)
    if source_path is not None:
        result["sql_source"] = source_path
    return result
