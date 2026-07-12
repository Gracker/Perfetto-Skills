from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "skills" / "perfetto-performance-analysis" / "scripts"
sys.path.insert(0, str(RUNTIME))


class PortableExpressionTest(unittest.TestCase):
    def setUp(self) -> None:
        from runtime.expressions import evaluate, validate

        self.evaluate = evaluate
        self.validate = validate
        self.context = {
            "enabled": True,
            "threshold": 3,
            "rows": {"data": [{"value": 5, "name": "RenderThread"}]},
            "empty": {"data": []},
        }

    def test_safe_expression_subset_covers_authored_step_conditions(self) -> None:
        self.assertTrue(
            self.evaluate(
                "enabled !== false && rows.data?.[0]?.value >= (threshold || 2)",
                self.context,
            )
        )
        self.assertTrue(self.evaluate("rows.data.length > 0", self.context))
        self.assertFalse(self.evaluate("empty.data?.[0]?.value === 1", self.context))
        self.assertTrue(self.evaluate("(rows.data[0].name || '').includes('Thread')", self.context))

    def test_expression_validator_rejects_code_execution(self) -> None:
        with self.assertRaises(ValueError):
            self.validate("__import__('os').system('id')")


class PortableRunnerTest(unittest.TestCase):
    def test_runner_preserves_empty_error_child_iterator_diagnostic_and_ai_states(self) -> None:
        from runtime.executor import SkillRunner

        manifest = {
            "skills": {
                "child": {
                    "id": "child",
                    "runtime_status": "executable",
                    "type": "atomic",
                    "inputs": [],
                    "query_id": "child/root",
                },
                "parent": {
                    "id": "parent",
                    "runtime_status": "executable",
                    "type": "composite",
                    "inputs": [{"name": "enabled", "type": "boolean", "required": False, "default": True}],
                    "steps": [
                        {"id": "seed", "type": "atomic", "query_id": "parent/seed", "save_as": "seed"},
                        {"id": "conditional", "type": "atomic", "query_id": "parent/conditional", "condition": "enabled && seed.data[0]?.run === 1"},
                        {"id": "empty", "type": "atomic", "query_id": "parent/empty", "on_empty": "nothing observed"},
                        {"id": "optional_error", "type": "atomic", "query_id": "parent/error", "optional": True},
                        {"id": "child", "type": "skill", "skill": "child", "save_as": "child_rows"},
                        {"id": "items", "type": "atomic", "query_id": "parent/items", "save_as": "items"},
                        {"id": "iter", "type": "iterator", "source": "items", "item_skill": "child", "max_items": 1},
                        {"id": "diagnose", "type": "diagnostic", "inputs": ["child_rows"], "rules": [{"condition": "child_rows.data[0]?.value === 2", "diagnosis": "confirmed", "confidence": "high"}]},
                        {"id": "summary", "type": "ai_summary"},
                    ],
                },
            }
        }

        def query(query_id, **_kwargs):
            if query_id == "parent/error":
                raise RuntimeError("query failed")
            return {
                "parent/seed": [{"run": 1}],
                "parent/conditional": [{"ok": 1}],
                "parent/empty": [],
                "parent/items": [{"item": 1}, {"item": 2}],
                "child/root": [{"value": 2}],
            }[query_id]

        first = SkillRunner(manifest, query).run("parent", {"enabled": True})
        second = SkillRunner(manifest, query).run("parent", {"enabled": True})
        by_id = {step["step_id"]: step for step in first["steps"]}
        self.assertTrue(first["success"])
        self.assertEqual(by_id["empty"]["status"], "empty")
        self.assertEqual(by_id["empty"]["message"], "nothing observed")
        self.assertEqual(by_id["optional_error"]["status"], "error")
        self.assertTrue(by_id["optional_error"]["optional"])
        self.assertEqual(len(by_id["iter"]["items"]), 1)
        self.assertEqual(by_id["diagnose"]["diagnostics"][0]["diagnosis"], "confirmed")
        self.assertEqual(by_id["summary"]["status"], "agent_action_required")
        self.assertEqual(first["evidence"][0]["evidence_id"], second["evidence"][0]["evidence_id"])

    def test_required_iterator_propagates_child_failure(self) -> None:
        from runtime.executor import SkillRunner

        manifest = {"skills": {
            "child": {
                "id": "child", "runtime_status": "executable", "type": "atomic",
                "inputs": [{"name": "item", "type": "integer", "required": True}],
                "query_id": "child/root",
            },
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "inputs": [],
                "steps": [
                    {"id": "items", "type": "atomic", "query_id": "parent/items", "save_as": "items"},
                    {"id": "iter", "type": "iterator", "source": "items", "item_skill": "child", "max_items": 2},
                ],
            },
        }}

        def query(query_id, **_kwargs):
            if query_id == "parent/items":
                return [{"item": 1}, {"item": 2}]
            raise RuntimeError("child query failed")

        result = SkillRunner(manifest, query).run("parent")
        iterator = next(step for step in result["steps"] if step["step_id"] == "iter")
        self.assertFalse(result["success"])
        self.assertEqual(iterator["status"], "error")
        self.assertEqual(iterator["failed_items"], 2)

    def test_optional_child_failure_is_explicit_without_failing_parent(self) -> None:
        from runtime.executor import SkillRunner

        manifest = {"skills": {
            "child": {
                "id": "child", "runtime_status": "executable", "type": "atomic",
                "inputs": [], "query_id": "child/root",
            },
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "inputs": [],
                "steps": [
                    {"id": "child", "type": "skill", "skill": "child", "optional": True},
                ],
            },
        }}

        def query(_query_id, **_kwargs):
            raise RuntimeError("capability unavailable")

        result = SkillRunner(manifest, query).run("parent")
        child = result["steps"][0]
        self.assertTrue(result["success"])
        self.assertEqual(child["status"], "error")
        self.assertTrue(child["optional"])


if __name__ == "__main__":
    unittest.main()
