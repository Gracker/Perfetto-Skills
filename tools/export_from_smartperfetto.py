#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "catalog" / "smartperfetto-export.json"
PUBLIC_SKILL = "perfetto-performance-analysis"
WORKFLOWS = {
    "trace-overview",
    "startup",
    "scrolling",
    "interaction",
    "anr-blocking",
    "cpu-scheduling",
    "memory",
    "gpu-rendering",
    "power-thermal",
    "io-network-media",
    "frameworks-games",
    "rendering-pipeline",
    "scene-reconstruction",
    "trace-comparison",
}

SKILL_WORKFLOW_OVERRIDES = {
    "android_dvfs_counter_stats": "cpu-scheduling",
    "android_kernel_wakelock_summary": "power-thermal",
    "ams_module": "startup",
    "art_module": "memory",
    "block_io_analysis": "io-network-media",
    "frame_blocking_calls": "scrolling",
    "launcher_module": "startup",
    "linux_perf_counter_hotspots": "cpu-scheduling",
    "pipeline_4feature_scoring": "rendering-pipeline",
    "pipeline_key_slices_overlay": "rendering-pipeline",
    "rendering_pipeline_detection": "rendering-pipeline",
    "suspend_wakeup_analysis": "power-thermal",
    "wakelock_tracking": "power-thermal",
    "wms_module": "interaction",
}


class ExportError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_output(source: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=source,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise ExportError(f"git {' '.join(args)} failed: {detail}")
    return completed.stdout.strip()


def source_state(source: Path) -> dict[str, Any]:
    return {
        "commit": git_output(source, "rev-parse", "HEAD"),
        "dirty": bool(git_output(source, "status", "--short")),
        "remote": git_output(source, "remote", "get-url", "origin"),
    }


def load_yaml(path: Path) -> dict[str, Any]:
    try:
        parsed = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ExportError(f"Invalid YAML in {path}: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ExportError(f"Expected a YAML mapping in {path}")
    return parsed


def skill_yaml_files(source: Path) -> list[Path]:
    return sorted((source / "backend" / "skills").rglob("*.skill.yaml"))


def is_runtime_candidate(path: Path, source: Path) -> bool:
    relative = path.relative_to(source).as_posix()
    return "/_template/" not in f"/{relative}" and path.name != "_base.skill.yaml"


def strategy_files(source: Path) -> list[Path]:
    root = source / "backend" / "strategies"
    return sorted(path for path in root.rglob("*") if path.is_file())


def pipeline_doc_files(source: Path) -> list[Path]:
    return sorted((source / "docs" / "rendering_pipelines").rglob("*.md"))


def classify_skill(name: str, raw: dict[str, Any]) -> str:
    skill_type = str(raw.get("type", ""))
    lowered = name.lower()
    if lowered in SKILL_WORKFLOW_OVERRIDES:
        return SKILL_WORKFLOW_OVERRIDES[lowered]
    if skill_type == "pipeline_definition":
        return "rendering-pipeline"
    if skill_type == "comparison" or "comparison" in lowered:
        return "trace-comparison"
    if lowered == "scene_reconstruction":
        return "scene-reconstruction"
    if any(
        token in lowered
        for token in (
            "flutter",
            "rn_",
            "react_native",
            "compose",
            "game_",
            "fpsgo",
            "launcher_module",
            "third_party_module",
        )
    ):
        return "frameworks-games"
    if "startup" in lowered or "app_process_starts" in lowered:
        return "startup"
    if any(
        token in lowered
        for token in ("click", "touch", "input", "navigation", "app_lifecycle")
    ):
        return "interaction"
    if any(
        token in lowered
        for token in ("anr", "binder", "blocking", "lock_", "contention", "futex")
    ):
        return "anr-blocking"
    if any(
        token in lowered
        for token in (
            "memory",
            "heap",
            "gc_",
            "_gc",
            "lmk",
            "oom",
            "dmabuf",
            "rss",
            "bitmap",
            "page_fault",
            "allocation",
        )
    ):
        return "memory"
    if any(
        token in lowered
        for token in (
            "power",
            "battery",
            "thermal",
            "wakelock",
            "doze",
            "screen_off",
            "energy",
            "rail",
        )
    ):
        return "power-thermal"
    if any(
        token in lowered
        for token in (
            "filesystem",
            "file_io",
            "block_io",
            "io_pressure",
            "network",
            "modem",
            "media",
            "codec",
            "logcat",
            "webview",
            "v8_",
        )
    ):
        return "io-network-media"
    if any(
        token in lowered
        for token in (
            "cpu",
            "sched",
            "irq",
            "runqueue",
            "affinity",
            "task_migration",
            "cache_miss",
            "system_load",
            "util_tracking",
            "wakeup_frequency",
        )
    ):
        return "cpu-scheduling"
    if any(
        token in lowered
        for token in (
            "gpu",
            "surfaceflinger",
            "sf_",
            "fence",
            "composition",
            "buffer_",
            "render_pipeline",
            "vrr_",
        )
    ):
        return "gpu-rendering"
    if any(
        token in lowered
        for token in (
            "scroll",
            "jank",
            "frame",
            "vsync",
            "choreographer",
            "render_thread",
        )
    ):
        return "scrolling"
    return "trace-overview"


def strategy_product_only_reason(path: Path) -> str | None:
    name = path.name
    product_only_prefixes = (
        "case-",
        "code-aware.",
        "prompt-complexity-",
        "prompt-final-report-missing-",
        "prompt-language-",
        "prompt-openai-",
        "prompt-quick.",
        "prompt-recent-",
        "prompt-role.",
        "prompt-session-",
        "runtime-correctness.",
    )
    if name.startswith(product_only_prefixes):
        return "SmartPerfetto runtime, session, case, language, or codebase orchestration"
    return None


def classify_strategy(path: Path) -> str:
    name = path.name.lower()
    if "comparison" in name:
        return "trace-comparison"
    if "scene-reconstruction" in name:
        return "scene-reconstruction"
    if "startup" in name:
        return "startup"
    if "scrolling" in name or "scroll-response" in name:
        return "scrolling"
    if "interaction" in name or "touch-tracking" in name:
        return "interaction"
    if "anr" in name or "binder" in name or "lock" in name or "thread-state" in name:
        return "anr-blocking"
    if "memory" in name or "gc-" in name or "data-sources" in name:
        return "memory"
    if "power" in name or "thermal" in name:
        return "power-thermal"
    if any(token in name for token in ("io.", "network", "media")):
        return "io-network-media"
    if "linux" in name or "cpu-scheduler" in name:
        return "cpu-scheduling"
    if any(token in name for token in ("pipeline", "rendering", "fences", "arch-")):
        return "rendering-pipeline"
    if "game" in name or "harmonyos" in name:
        return "frameworks-games"
    return "trace-overview"


def destination_for_strategy(path: Path) -> str:
    directory = "knowledge" if path.name.startswith("knowledge-") else "strategies"
    suffix = ".md" if path.suffix != ".md" else ""
    return f"references/generated/{directory}/{path.name}{suffix}"


def bootstrap_policy(source: Path) -> dict[str, Any]:
    skills: dict[str, Any] = {}
    for path in skill_yaml_files(source):
        if not is_runtime_candidate(path, source):
            continue
        raw = load_yaml(path)
        name = raw.get("name")
        if not isinstance(name, str) or not name:
            raise ExportError(f"Runtime Skill has no name: {path}")
        if name in skills:
            raise ExportError(f"Duplicate runtime Skill name: {name}")
        skills[name] = {
            "source": path.relative_to(source).as_posix(),
            "workflow": classify_skill(name, raw),
            "disposition": "exported",
            "destination": f"references/generated/skills/{name}.md",
        }

    strategies: dict[str, Any] = {}
    for path in strategy_files(source):
        relative = path.relative_to(source).as_posix()
        reason = strategy_product_only_reason(path)
        if reason:
            strategies[relative] = {
                "disposition": "product-only",
                "reason": reason,
            }
        else:
            strategies[relative] = {
                "workflow": classify_strategy(path),
                "disposition": "exported",
                "destination": destination_for_strategy(path),
            }

    pipeline_docs: dict[str, Any] = {}
    for path in pipeline_doc_files(source):
        relative = path.relative_to(source).as_posix()
        pipeline_docs[relative] = {
            "disposition": "exported",
            "destination": f"references/generated/pipelines/docs/{path.name}",
        }

    return {
        "version": 1,
        "public_skill": PUBLIC_SKILL,
        "excluded_runtime_paths": [
            "backend/skills/_template/",
            "backend/skills/pipelines/_base.skill.yaml",
        ],
        "skills": skills,
        "strategies": strategies,
        "pipeline_docs": pipeline_docs,
    }


def write_text_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as handle:
            temporary = Path(handle.name)
            handle.write(content)
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def write_bootstrap_policy(path: Path, policy: dict[str, Any]) -> None:
    if path.exists():
        raise ExportError(f"Refusing to overwrite existing export policy: {path}")
    header = (
        "# SPDX-License-Identifier: AGPL-3.0-or-later\n"
        "# Copyright (C) 2024-2026 Gracker (Chris)\n"
        "# Explicit public Agent Skill projection policy. New source files must be classified.\n\n"
    )
    serialized = yaml.safe_dump(
        policy,
        sort_keys=False,
        allow_unicode=True,
        width=120,
    )
    write_text_atomic(path, header + serialized)


def validate_policy_sources(
    source: Path,
    policy: dict[str, Any],
    runtime_files: list[Path],
    strategies: list[Path],
    pipeline_docs: list[Path],
) -> None:
    if policy.get("version") != 1 or policy.get("public_skill") != PUBLIC_SKILL:
        raise ExportError("Unsupported public export policy version or public_skill")

    runtime_by_name: dict[str, str] = {}
    for path in runtime_files:
        raw = load_yaml(path)
        name = raw.get("name")
        if not isinstance(name, str):
            raise ExportError(f"Runtime Skill has no string name: {path}")
        if name in runtime_by_name:
            raise ExportError(f"Duplicate runtime Skill name: {name}")
        runtime_by_name[name] = path.relative_to(source).as_posix()

    policy_skills = policy.get("skills")
    if not isinstance(policy_skills, dict):
        raise ExportError("Policy skills must be a mapping")
    missing = sorted(set(runtime_by_name) - set(policy_skills))
    stale = sorted(set(policy_skills) - set(runtime_by_name))
    if missing or stale:
        raise ExportError(f"Policy Skill mismatch: missing={missing}, stale={stale}")
    for name, relative in runtime_by_name.items():
        config = policy_skills[name]
        if not isinstance(config, dict) or config.get("source") != relative:
            raise ExportError(f"Policy source mismatch for Skill {name}: {relative}")

    for key, current_paths in (
        ("strategies", strategies),
        ("pipeline_docs", pipeline_docs),
    ):
        mapping = policy.get(key)
        if not isinstance(mapping, dict):
            raise ExportError(f"Policy {key} must be a mapping")
        current = {path.relative_to(source).as_posix() for path in current_paths}
        missing_paths = sorted(current - set(mapping))
        stale_paths = sorted(set(mapping) - current)
        if missing_paths or stale_paths:
            raise ExportError(
                f"Policy {key} mismatch: missing={missing_paths}, stale={stale_paths}"
            )


def validate_disposition(config: dict[str, Any], label: str) -> None:
    disposition = config.get("disposition")
    if disposition not in {"exported", "merged", "product-only"}:
        raise ExportError(f"Invalid disposition for {label}: {disposition}")
    if disposition == "product-only":
        if not config.get("reason"):
            raise ExportError(f"Product-only source requires a reason: {label}")
        return
    if config.get("workflow") not in WORKFLOWS:
        raise ExportError(f"Invalid workflow for {label}: {config.get('workflow')}")
    if not config.get("destination"):
        raise ExportError(f"Exported source requires a destination: {label}")


def build_catalog(source: Path, policy_path: Path) -> dict[str, Any]:
    state = source_state(source)
    all_skills = skill_yaml_files(source)
    runtime_files = [path for path in all_skills if is_runtime_candidate(path, source)]
    strategies = strategy_files(source)
    pipeline_docs = pipeline_doc_files(source)
    policy = load_yaml(policy_path)
    validate_policy_sources(
        source, policy, runtime_files, strategies, pipeline_docs
    )

    policy_skills = policy["skills"]
    skill_entries: list[dict[str, Any]] = []
    runtime_types: Counter[str] = Counter()
    for name in sorted(policy_skills):
        config = policy_skills[name]
        validate_disposition(config, f"Skill {name}")
        path = source / config["source"]
        raw = load_yaml(path)
        runtime_type = str(raw.get("type", "unknown"))
        runtime_types[runtime_type] += 1
        entry = {
            "name": name,
            "source_path": config["source"],
            "source_sha256": sha256_file(path),
            "version": str(raw.get("version", "1.0")),
            "runtime_type": runtime_type,
            "category": raw.get("category"),
            "tier": raw.get("tier"),
            "workflow": config.get("workflow"),
            "disposition": config["disposition"],
            "destination": config.get("destination"),
            "reason": config.get("reason"),
        }
        skill_entries.append({key: value for key, value in entry.items() if value is not None})

    strategy_entries: list[dict[str, Any]] = []
    for relative in sorted(policy["strategies"]):
        config = policy["strategies"][relative]
        validate_disposition(config, relative)
        path = source / relative
        entry = {
            "source_path": relative,
            "source_sha256": sha256_file(path),
            "workflow": config.get("workflow"),
            "disposition": config["disposition"],
            "destination": config.get("destination"),
            "reason": config.get("reason"),
        }
        strategy_entries.append(
            {key: value for key, value in entry.items() if value is not None}
        )

    pipeline_entries: list[dict[str, Any]] = []
    for relative in sorted(policy["pipeline_docs"]):
        config = policy["pipeline_docs"][relative]
        disposition = config.get("disposition")
        if disposition != "exported" or not config.get("destination"):
            raise ExportError(f"Pipeline doc must be exported: {relative}")
        path = source / relative
        pipeline_entries.append(
            {
                "source_path": relative,
                "source_sha256": sha256_file(path),
                "disposition": disposition,
                "destination": config["destination"],
            }
        )

    exported_strategies = sum(
        entry["disposition"] != "product-only" for entry in strategy_entries
    )
    return {
        "schema_version": 1,
        "public_skill": PUBLIC_SKILL,
        "source": {
            "repository": state["remote"],
            "commit": state["commit"],
            "dirty": state["dirty"],
            "policy_path": policy_path.relative_to(source).as_posix(),
            "policy_sha256": sha256_file(policy_path),
        },
        "summary": {
            "skill_yaml_files": len(all_skills),
            "runtime_candidates": len(runtime_files),
            "excluded_skill_definitions": len(all_skills) - len(runtime_files),
            "runtime_types": dict(sorted(runtime_types.items())),
            "strategy_sources": len(strategy_entries),
            "exported_strategy_sources": exported_strategies,
            "product_only_strategy_sources": len(strategy_entries) - exported_strategies,
            "pipeline_docs": len(pipeline_entries),
        },
        "skills": skill_entries,
        "strategies": strategy_entries,
        "pipeline_docs": pipeline_entries,
    }


def serialize_catalog(catalog: dict[str, Any]) -> str:
    return json.dumps(
        catalog,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Export a deterministic public Agent Skill catalog from SmartPerfetto."
    )
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--policy", type=Path)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--bootstrap-policy", type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true")
    args = parser.parse_args(argv)

    source = args.source.expanduser().resolve()
    if not (source / ".git").exists():
        raise ExportError(f"SmartPerfetto source is not a Git checkout: {source}")
    state = source_state(source)

    if args.bootstrap_policy:
        if state["dirty"]:
            raise ExportError("Refusing to bootstrap policy from a dirty SmartPerfetto checkout")
        policy = bootstrap_policy(source)
        destination = args.bootstrap_policy.expanduser().resolve()
        write_bootstrap_policy(destination, policy)
        print(
            f"Bootstrapped {len(policy['skills'])} Skills, "
            f"{len(policy['strategies'])} strategy sources, and "
            f"{len(policy['pipeline_docs'])} pipeline docs to {destination}"
        )
        return 0

    if state["dirty"] and not args.allow_dirty:
        raise ExportError("SmartPerfetto checkout is dirty; commit source changes before export")
    policy_path = (
        args.policy.expanduser().resolve()
        if args.policy
        else source / "backend" / "skills" / "public-export.yaml"
    )
    catalog = build_catalog(source, policy_path)
    serialized = serialize_catalog(catalog)
    output = args.output.expanduser().resolve()
    if args.check:
        if not output.is_file():
            raise ExportError(f"Catalog is missing: {output}")
        current = output.read_text(encoding="utf-8")
        if current != serialized:
            raise ExportError(
                f"Catalog drift detected: run {Path(__file__).name} --source {source}"
            )
        print(f"Catalog is current: {output}")
        return 0
    write_text_atomic(output, serialized)
    print(
        f"Exported {catalog['summary']['runtime_candidates']} runtime Skills, "
        f"{catalog['summary']['strategy_sources']} strategy sources, and "
        f"{catalog['summary']['pipeline_docs']} pipeline docs to {output}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ExportError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(2)
