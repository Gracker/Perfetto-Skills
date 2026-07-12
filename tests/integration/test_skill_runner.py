import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests.support import SCRIPTS, trace_processor


TRACE_ROOT = Path(os.environ["SMARTPERFETTO_TEST_TRACES"]) if os.environ.get("SMARTPERFETTO_TEST_TRACES") else None
SOURCE = Path(os.environ["SMARTPERFETTO_SOURCE"]) if os.environ.get("SMARTPERFETTO_SOURCE") else None


def required_execution_errors(result: dict[str, object]) -> list[str]:
    errors: list[str] = []

    def visit(run: dict[str, object], path: str = "", optional_branch: bool = False) -> None:
        for step in run.get("steps", []):
            label = f"{path}/{step['step_id']}"
            step_optional = optional_branch or bool(step.get("optional"))
            if not step_optional and step["status"] in {"error", "unsupported"}:
                errors.append(f"{label}: {step.get('error', step['status'])}")
            if isinstance(step.get("child"), dict):
                visit(step["child"], label, step_optional)
            for item in step.get("items", []):
                visit(item["result"], label, step_optional)

    visit(result)
    return errors


@unittest.skipUnless(TRACE_ROOT and TRACE_ROOT.is_dir(), "SMARTPERFETTO_TEST_TRACES not configured")
class SkillRunnerIntegrationTest(unittest.TestCase):
    def test_representative_complete_skill_graphs_run_without_hidden_step_errors(self) -> None:
        cases = [
            ("startup_analysis", "launch_light.pftrace", []),
            ("scrolling_analysis", "scroll_Standard-AOSP-App-Without-PreAnimation.pftrace", []),
            ("anr_analysis", "launch_light.pftrace", []),
            ("memory_analysis", "launch_light.pftrace", []),
            (
                "rendering_pipeline_detection",
                "Scroll-Flutter-327-TextureView.pftrace",
                ["--param", 'package="com.example.friendscircle.v27.textureview"'],
            ),
            (
                "callstack_analysis",
                (
                    SOURCE / "perfetto/test/data/callstack_sampling.pftrace"
                    if SOURCE
                    else TRACE_ROOT / "launch_light.pftrace"
                ),
                [],
            ),
            (
                "jank_frame_detail",
                "scroll-demo-customer-scroll.pftrace",
                [
                    "--param", "start_ts=506731768732822",
                    "--param", "end_ts=506731787394072",
                    "--param", "frame_ts=506731768732822",
                    "--param", "frame_dur=18661250",
                    "--param", "dur_ms=18.66125",
                    "--param", "frame_id=59665037",
                    "--param", 'package="com.example.wechatfriendforcustomscroller"',
                    "--param", 'jank_type="App Deadline Missed"',
                ],
            ),
        ]
        with tempfile.TemporaryDirectory() as temporary:
            for skill_id, filename, extra in cases:
                with self.subTest(skill=skill_id):
                    output = Path(temporary) / skill_id
                    command = [
                        sys.executable,
                        str(SCRIPTS / "perfetto_skill.py"),
                        "run",
                        str(filename if isinstance(filename, Path) else TRACE_ROOT / filename),
                        "--skill",
                        skill_id,
                        "--trace-processor",
                        trace_processor(),
                        "--output-dir",
                        str(output),
                        *extra,
                    ]
                    completed = subprocess.run(
                        command, check=False, capture_output=True, text=True
                    )
                    self.assertEqual(completed.returncode, 0, completed.stderr)
                    result = json.loads((output / "result.json").read_text(encoding="utf-8"))
                    self.assertTrue(result["success"], result)
                    self.assertEqual(result["processor"]["status"], "verified")
                    self.assertEqual(required_execution_errors(result), [])
                    self.assertGreater(len(result["evidence"]), 0)
                    self.assertTrue(
                        all(item.get("processor", {}).get("status") == "verified" for item in result["evidence"]),
                        result["evidence"],
                    )


if __name__ == "__main__":
    unittest.main()
