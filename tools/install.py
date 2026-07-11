#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SKILL_NAME = "perfetto-performance-analysis"
CANONICAL_SKILL = ROOT / "skills" / SKILL_NAME
CLIENT_PATHS = {
    "codex": Path(".agents/skills"),
    "claude-code": Path(".claude/skills"),
    "opencode": Path(".opencode/skills"),
}
COPY_IGNORE = shutil.ignore_patterns(
    "__pycache__",
    "*.pyc",
    "*.pyo",
    ".DS_Store",
    ".perfetto-cache",
)


def validate_skill_tree(path: Path) -> None:
    required = (
        path / "SKILL.md",
        path / "scripts" / "perfetto_query.py",
        path / "references" / "workflow-index.json",
    )
    missing = [item.relative_to(path).as_posix() for item in required if not item.is_file()]
    if missing:
        raise ValueError(f"Skill tree is incomplete: {missing}")


def resolve_destination(
    client: str | None,
    destination: Path | None,
    home: Path,
) -> Path:
    if destination is not None:
        return destination.expanduser().resolve()
    if client not in CLIENT_PATHS:
        raise ValueError("Choose a supported client or provide --destination")
    return (home.expanduser().resolve() / CLIENT_PATHS[client]).resolve()


def install_skill(
    destination: Path,
    *,
    force: bool,
    source: Path = CANONICAL_SKILL,
) -> Path:
    source = source.expanduser().resolve()
    validate_skill_tree(source)
    destination = destination.expanduser().resolve()
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / SKILL_NAME
    target_exists = target.exists() or target.is_symlink()
    if target_exists and not force:
        raise FileExistsError(f"Skill is already installed: {target}")

    stage_parent = Path(
        tempfile.mkdtemp(prefix=f".{SKILL_NAME}.install-", dir=destination)
    )
    staged = stage_parent / SKILL_NAME
    backup: Path | None = None
    try:
        shutil.copytree(source, staged, ignore=COPY_IGNORE, symlinks=False)
        validate_skill_tree(staged)
        if target_exists:
            backup = Path(
                tempfile.mkdtemp(prefix=f".{SKILL_NAME}.backup-", dir=destination)
            )
            backup.rmdir()
            os.replace(target, backup)
        try:
            os.replace(staged, target)
        except BaseException:
            if backup is not None and backup.exists() and not target.exists():
                os.replace(backup, target)
                backup = None
            raise
        if backup is not None:
            if backup.is_dir() and not backup.is_symlink():
                shutil.rmtree(backup)
            else:
                backup.unlink(missing_ok=True)
            backup = None
    finally:
        if backup is not None and backup.exists() and not target.exists():
            os.replace(backup, target)
        shutil.rmtree(stage_parent, ignore_errors=True)
    return target


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Install Perfetto Performance Analysis for an Agent Skills client."
    )
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--client", choices=sorted(CLIENT_PATHS))
    selection.add_argument("--destination", type=Path)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)
    destination = resolve_destination(args.client, args.destination, args.home)
    installed = install_skill(destination, force=args.force)
    print(f"Installed {SKILL_NAME} to {installed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
