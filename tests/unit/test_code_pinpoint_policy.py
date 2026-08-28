import sqlite3
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SQL_PATH = ROOT / "src/overrides/sql/code_pinpoint/hot_slices.sql"


def render_sql(package: str) -> str:
    source = SQL_PATH.read_text(encoding="utf-8")
    source = source.replace("INCLUDE PERFETTO MODULE slices.with_context;", "")
    return (
        source.replace("${package}", package.replace("'", "''"))
        .replace("${start_ts}", "NULL")
        .replace("${end_ts}", "NULL")
    )


class CodePinpointPolicyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.database = sqlite3.connect(":memory:")
        self.database.row_factory = sqlite3.Row
        self.database.execute(
            """
            CREATE TABLE thread_slice (
              id INTEGER,
              ts INTEGER,
              dur INTEGER,
              upid INTEGER,
              utid INTEGER,
              process_name TEXT,
              thread_name TEXT,
              is_main_thread INTEGER,
              name TEXT
            )
            """
        )
        rows = [
            (1, "com.example.app", "main", 1, "ChaosTask"),
            (2, "com.example.app", "main", 1, "StartupLoadMarker"),
            (3, "com.example.app:worker", "worker-main", 1, "WorkerLoadMarker"),
            (4, "com.example.app", "main", 1, "Flutter::BeginFrame"),
            (5, "com.example.app", "main", 1, "RN::FabricCommit"),
            (6, "com.example.app", "main", 1, "WebView::DrawFun"),
            (7, "com.example.app", "main", 1, "Choreographer#doFrame"),
            (8, "com.example.app", "main", 1, "FabricMount::executeMount"),
            (9, "com.example.app", "RenderThread", 0, "DrawFrame"),
            (10, "com.example.app", "main", 1, "generic trace span"),
            (11, "com.example.app", "main", 1, "lowercaseLabel"),
            (12, "com.example.app", "main", 1, "Lcom/example/app/Marker;"),
            (13, "com.example.app2", "main", 1, "OtherPackageMarker"),
        ]
        self.database.executemany(
            "INSERT INTO thread_slice VALUES (?, ?, 100, 10, 20, ?, ?, ?, ?)",
            [(row_id, row_id * 1000, process, thread, main, name) for row_id, process, thread, main, name in rows],
        )

    def tearDown(self) -> None:
        self.database.close()

    def test_classifies_only_bounded_main_thread_app_labels(self) -> None:
        actual = {
            row["slice_name"]: (row["anchor_kind"], row["source_query_hint"])
            for row in self.database.execute(render_sql("com.example.app"))
        }

        for name in ("ChaosTask", "StartupLoadMarker", "WorkerLoadMarker"):
            self.assertEqual(actual[name], ("app_trace_label", name))
        for name in (
            "Flutter::BeginFrame",
            "RN::FabricCommit",
            "WebView::DrawFun",
            "Choreographer#doFrame",
            "FabricMount::executeMount",
            "DrawFrame",
            "generic trace span",
            "lowercaseLabel",
            "Lcom/example/app/Marker;",
        ):
            self.assertEqual(actual[name], ("generic_anchor_only", None), name)
        self.assertNotIn("OtherPackageMarker", actual)

    def test_package_metacharacters_are_literal(self) -> None:
        self.assertEqual(list(self.database.execute(render_sql("com.example.ap?"))), [])


if __name__ == "__main__":
    unittest.main()
