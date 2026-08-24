import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tools.upstream_locks import (
    build_generated_base,
    load_and_validate_android_skills_lock,
    load_and_validate_google_lock,
    load_and_validate_smartperfetto_lock,
)
from tools.compile_skill import compile_tree


ROOT = Path(__file__).resolve().parents[2]


class UpstreamLockTest(unittest.TestCase):
    def test_committed_locks_are_immutable_and_consistent(self) -> None:
        smart = load_and_validate_smartperfetto_lock(
            ROOT / "upstreams/smartperfetto.lock.json"
        )
        google = load_and_validate_google_lock(
            ROOT / "upstreams/google-perfetto.lock.json"
        )
        android = load_and_validate_android_skills_lock(
            ROOT / "upstreams/android-skills.lock.json"
        )
        self.assertEqual(smart["commit"], "9d0d444f8891a0fc47d7ede0da6ef5f758f9ede4")
        self.assertEqual(google["schema_version"], 2)
        self.assertEqual(google["official_reference"]["tag"], "v57.2")
        self.assertEqual(
            google["official_reference"]["commit"],
            "da1d152cff27890903d158fe96751de3aab883cc",
        )
        self.assertEqual(
            google["runtime"]["revision"],
            "7b573c1c00f5d5890f496a87b4876a995b6a1c66",
        )
        self.assertEqual(google["runtime"]["reported_version"], "v57.2")
        self.assertEqual(
            google["official_reference"]["skill"]["role"], "gap_check_only"
        )
        runtime_stdlib = json.loads(
            (
                ROOT / "upstreams/snapshots/google-perfetto/stdlib-index.json"
            ).read_text(encoding="utf-8")
        )
        runtime_modules = {item["module"] for item in runtime_stdlib["modules"]}
        self.assertIn("android.memory.heap_profile.intervals", runtime_modules)
        self.assertNotIn("std.trees.filter", runtime_modules)
        self.assertEqual(
            android["commit"], "47e1dff74a5cde5d0128c5d15e74e000323135ea"
        )
        self.assertEqual(android["role"], "gap_check_only")
        self.assertEqual(android["schema_version"], 2)
        self.assertNotIn("snapshot_path", android)
        self.assertNotIn("snapshot_sha256", android)
        self.assertFalse(
            (ROOT / "upstreams/snapshots/android-skills").exists(),
            "gap-check-only Android guidance must never be stored as a snapshot",
        )

    def test_committed_base_tree_matches_manifest_and_generated_output(self) -> None:
        base_root = ROOT / "upstreams/snapshots/smartperfetto/base/references/generated"
        current = build_generated_base(base_root)
        manifest = load_and_validate_smartperfetto_lock(
            ROOT / "upstreams/smartperfetto.lock.json"
        )["generated_base"]
        self.assertEqual(current, manifest)
        generated_root = ROOT / "skills/perfetto-performance-analysis/references/generated"
        with tempfile.TemporaryDirectory() as temporary:
            candidate = Path(temporary) / "generated"
            compile_tree(
                base_root,
                ROOT / "src/overrides",
                candidate,
                owned_fixture_manifest=ROOT / "fixtures/manifest.json",
            )
            self.assertEqual(
                build_generated_base(candidate),
                build_generated_base(generated_root),
            )

    def test_generated_base_is_deterministic_and_rejects_symlinks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "b").mkdir()
            (root / "b/file.txt").write_text("b", encoding="utf-8")
            (root / "a.txt").write_text("a", encoding="utf-8")
            first = build_generated_base(root)
            second = build_generated_base(root)
            self.assertEqual(first, second)
            (root / "link").symlink_to(root / "a.txt")
            with self.assertRaises(ValueError):
                build_generated_base(root)

    def test_google_lock_rejects_forged_snapshot_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            upstreams = root / "upstreams"
            snapshots = upstreams / "snapshots/google-perfetto"
            snapshots.mkdir(parents=True)
            lock_source = ROOT / "upstreams/google-perfetto.lock.json"
            lock = upstreams / "google-perfetto.lock.json"
            shutil.copyfile(lock_source, lock)
            for name in ("official-skill.json", "stdlib-index.json"):
                shutil.copyfile(
                    ROOT / "upstreams/snapshots/google-perfetto" / name,
                    snapshots / name,
                )
            processor_lock = (
                root
                / "skills/perfetto-performance-analysis/references/trace-processor-lock.json"
            )
            processor_lock.parent.mkdir(parents=True)
            shutil.copyfile(
                ROOT
                / "skills/perfetto-performance-analysis/references/trace-processor-lock.json",
                processor_lock,
            )
            load_and_validate_google_lock(lock)
            stdlib = snapshots / "stdlib-index.json"
            stdlib.write_text(
                stdlib.read_text(encoding="utf-8").replace(
                    '"modules": [', '"modules": [{"module":"forged"},'
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "snapshot bytes"):
                load_and_validate_google_lock(lock)

    def test_google_lock_rejects_trace_lock_identity_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            upstreams = root / "upstreams"
            snapshots = upstreams / "snapshots/google-perfetto"
            snapshots.mkdir(parents=True)
            document = json.loads(
                (ROOT / "upstreams/google-perfetto.lock.json").read_text(
                    encoding="utf-8"
                )
            )
            trace_path = (
                root
                / document["runtime"]["trace_processor"]["lock_path"]
            )
            trace_path.parent.mkdir(parents=True)
            trace = json.loads(
                (
                    ROOT
                    / "skills/perfetto-performance-analysis/references/trace-processor-lock.json"
                ).read_text(encoding="utf-8")
            )
            trace["revision"] = "c" * 40
            trace_path.write_text(json.dumps(trace), encoding="utf-8")
            document["runtime"]["trace_processor"]["lock_sha256"] = hashlib.sha256(
                trace_path.read_bytes()
            ).hexdigest()
            lock_path = upstreams / "google-perfetto.lock.json"
            lock_path.write_text(json.dumps(document), encoding="utf-8")
            for name in ("official-skill.json", "stdlib-index.json"):
                shutil.copyfile(
                    ROOT / "upstreams/snapshots/google-perfetto" / name,
                    snapshots / name,
                )
            with self.assertRaisesRegex(ValueError, "revision"):
                load_and_validate_google_lock(lock_path, validate_snapshots=False)

    def test_android_lock_rejects_snapshot_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            upstreams = Path(temporary) / "upstreams"
            upstreams.mkdir(parents=True)
            lock = upstreams / "android-skills.lock.json"
            shutil.copyfile(ROOT / "upstreams/android-skills.lock.json", lock)
            document = json.loads(lock.read_text(encoding="utf-8"))
            document["snapshot_path"] = "snapshots/android-skills/profilers.json"
            lock.write_text(json.dumps(document), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "must not persist snapshots"):
                load_and_validate_android_skills_lock(lock)

    def test_android_lock_rejects_snapshot_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            upstreams = Path(temporary) / "upstreams"
            upstreams.mkdir(parents=True)
            lock = upstreams / "android-skills.lock.json"
            shutil.copyfile(ROOT / "upstreams/android-skills.lock.json", lock)
            snapshot = upstreams / "snapshots/android-skills/profilers.json"
            snapshot.parent.mkdir(parents=True)
            snapshot.write_text("copied upstream material", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "must not persist snapshots"):
                load_and_validate_android_skills_lock(lock)


if __name__ == "__main__":
    unittest.main()
