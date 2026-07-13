from pathlib import Path
import shutil
import tempfile
import unittest

from tools.upstream_locks import (
    build_generated_base,
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
        self.assertEqual(smart["commit"], "a0c1029d26be661802c6ac4b6ae26ded35c8db31")
        self.assertEqual(google["tag"], "v57.2")
        self.assertEqual(google["official_skill"]["role"], "gap_check_only")

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


if __name__ == "__main__":
    unittest.main()
