import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.integration.test_fixture_manifest import assert_semantic_assertion
from tests.support import SCRIPTS, fixture_path, trace_processor
from tools.overlays import load_overlays


ROOT = Path(__file__).resolve().parents[2]
OVERLAYS = [
    overlay
    for overlay in load_overlays(ROOT / "src/overrides")
    if overlay.kind == "sql"
]


def base_query_sql(
    query: dict[str, object],
    descriptors_by_id: dict[str, dict[str, object]],
    base: Path,
) -> tuple[str, set[str]]:
    ordered_sql: list[str] = []
    modules: set[str] = set()
    visited: set[str] = set()

    def append(current: dict[str, object]) -> None:
        query_id = str(current["id"])
        if query_id in visited:
            return
        dependencies = current["sql_dependencies"]
        for setup_id in dependencies["setup_queries"]:
            append(descriptors_by_id[setup_id])
        visited.add(query_id)
        modules.update(dependencies["declared_modules"])
        ordered_sql.append((base / str(current["path"])).read_text(encoding="utf-8"))

    append(query)
    return "\n\n".join(ordered_sql), modules


@unittest.skipUnless(
    OVERLAYS and os.environ.get("PERFETTO_FIXTURE_ROOT") and os.environ.get("PERFETTO_TRACE_PROCESSOR"),
    "no configured local SQL overlay regressions",
)
class LocalSqlOverlayRegressionTest(unittest.TestCase):
    def test_base_fails_and_compiled_overlay_passes_owned_real_trace_assertion(self) -> None:
        manifest = json.loads((ROOT / "fixtures/manifest.json").read_text(encoding="utf-8"))
        assertions = {
            assertion["id"]: (fixture, assertion)
            for fixture in manifest["fixtures"]
            for assertion in fixture["assertions"]
        }
        generated = ROOT / "skills/perfetto-performance-analysis/references/generated"
        base = ROOT / "upstreams/snapshots/smartperfetto/base/references/generated"
        query_descriptors = {}
        descriptors_by_id = {}
        for shard in (generated / "runtime/queries").glob("*.json"):
            for query in json.loads(shard.read_text(encoding="utf-8"))["queries"]:
                query_descriptors[query["path"]] = query
                descriptors_by_id[query["id"]] = query
        with tempfile.TemporaryDirectory() as temporary:
            for overlay in OVERLAYS:
                query = query_descriptors[overlay.target]
                for regression_id in overlay.regression_ids:
                    fixture, assertion = assertions[regression_id]
                    trace = fixture_path(fixture["id"])
                    compiled_output = Path(temporary) / f"{regression_id}-compiled.json"
                    compiled = subprocess.run(
                        [
                            sys.executable,
                            str(SCRIPTS / "perfetto_query.py"),
                            str(trace),
                            "--query-id",
                            query["id"],
                            "--trace-processor",
                            trace_processor(),
                            "--output",
                            str(compiled_output),
                            *sum(
                                (
                                    ["--param", f"{name}={json.dumps(value)}"]
                                    for name, value in sorted(assertion.get("params", {}).items())
                                ),
                                [],
                            ),
                        ],
                        check=False,
                        capture_output=True,
                        text=True,
                        timeout=60,
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)
                    assert_semantic_assertion(
                        self,
                        json.loads(compiled_output.read_text(encoding="utf-8")),
                        assertion,
                    )

                    base_output = Path(temporary) / f"{regression_id}-base.json"
                    sql, modules = base_query_sql(query, descriptors_by_id, base)
                    command = [
                        sys.executable,
                        str(SCRIPTS / "perfetto_query.py"),
                        str(trace),
                        "--sql",
                        sql,
                        "--trace-processor",
                        trace_processor(),
                        "--output",
                        str(base_output),
                    ]
                    for module in sorted(modules):
                        command.extend(("--module", module))
                    for name, value in sorted(assertion.get("params", {}).items()):
                        command.extend(("--param", f"{name}={json.dumps(value)}"))
                    base_run = subprocess.run(
                        command,
                        check=False,
                        capture_output=True,
                        text=True,
                        timeout=60,
                    )
                    failure = base_run.stderr
                    if base_run.returncode == 0:
                        try:
                            assert_semantic_assertion(
                                self,
                                json.loads(base_output.read_text(encoding="utf-8")),
                                assertion,
                            )
                        except AssertionError as error:
                            failure = str(error)
                        else:
                            self.fail(f"base unexpectedly passed: {regression_id}")
                    self.assertIn(overlay.base_failure_signature, failure)


if __name__ == "__main__":
    unittest.main()
