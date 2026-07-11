import hashlib
from pathlib import Path
import tempfile
import unittest

import yaml

from tools import install


ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "skills" / "perfetto-performance-analysis"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class InstallerTest(unittest.TestCase):
    def test_installs_canonical_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / ".agents" / "skills"
            installed = install.install_skill(destination, force=False)
            self.assertEqual(
                installed, (destination / "perfetto-performance-analysis").resolve()
            )
            self.assertEqual(sha256(installed / "SKILL.md"), sha256(CANONICAL / "SKILL.md"))
            self.assertFalse(any(installed.rglob("__pycache__")))

    def test_refuses_overwrite_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            install.install_skill(destination, force=False)
            with self.assertRaises(FileExistsError):
                install.install_skill(destination, force=False)

    def test_force_replaces_existing_install(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            installed = install.install_skill(destination, force=False)
            (installed / "stale.txt").write_text("stale", encoding="utf-8")
            replaced = install.install_skill(destination, force=True)
            self.assertEqual(replaced, installed)
            self.assertFalse((replaced / "stale.txt").exists())
            self.assertEqual(sha256(replaced / "SKILL.md"), sha256(CANONICAL / "SKILL.md"))

    def test_client_destinations_are_resolved_under_home(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            for client, relative in install.CLIENT_PATHS.items():
                with self.subTest(client=client):
                    self.assertEqual(
                        install.resolve_destination(client, None, home),
                        (home / relative).resolve(),
                    )

    def test_openai_metadata_is_optional_and_portable(self) -> None:
        metadata = yaml.safe_load(
            (CANONICAL / "agents" / "openai.yaml").read_text(encoding="utf-8")
        )
        self.assertEqual(set(metadata), {"interface"})
        self.assertEqual(
            set(metadata["interface"]),
            {"display_name", "short_description", "default_prompt"},
        )
        self.assertIn(
            "$perfetto-performance-analysis", metadata["interface"]["default_prompt"]
        )


if __name__ == "__main__":
    unittest.main()
