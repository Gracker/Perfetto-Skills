#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "catalog" / "smartperfetto-export.json"
MIGRATION_COVERAGE = ROOT / "docs" / "migration-coverage.md"
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
GENERATED_PREFIX = Path("references/generated")
SKILL_ROOT = ROOT / "skills" / PUBLIC_SKILL
SKILL_SCRIPTS = SKILL_ROOT / "scripts"
if str(SKILL_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SKILL_SCRIPTS))

from runtime.expressions import validate as validate_expression  # noqa: E402
SUPPORTED_STEP_TYPES = {
    "atomic",
    "skill",
    "diagnostic",
    "iterator",
    "ai_summary",
}
ANDROID_API_LEVELS = tuple(range(28, 38))
CAPABILITY_STATES = (
    "unsupported",
    "not_recorded",
    "recorded_empty",
    "recorded_populated",
    "unknown",
)
PERSISTENT_OBJECT = re.compile(
    r"\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:PERFETTO\s+)?"
    r"(?P<kind>TABLE|VIEW|FUNCTION|MACRO)\s+(?:IF\s+NOT\s+EXISTS\s+)?"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
DROP_OBJECT = re.compile(
    r"\bDROP\s+(?P<kind>TABLE|VIEW|FUNCTION|MACRO)\s+"
    r"(?:IF\s+EXISTS\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
PRODUCT_RUNTIME_PATTERN = re.compile(
    r"\b(?:submit_plan|invoke_skill|create_artifact|fetch_artifact|load_artifact|"
    r"get_artifact|artifact_api|session_state|navigate_timeline|pin_tracks)\b"
    r"|SmartPerfetto(?:\s+UI)?",
    re.IGNORECASE,
)

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


_GITHUB_REMOTE = re.compile(
    r"^(?:git@github\.com:|ssh://git@github\.com/|https?://github\.com/)"
    r"(?P<slug>[^/]+/[^/]+?)(?:\.git)?/?$",
    re.IGNORECASE,
)


def canonical_repository(remote: str) -> str:
    match = _GITHUB_REMOTE.fullmatch(remote.strip())
    if match:
        return f"https://github.com/{match.group('slug')}"
    return remote.strip().removesuffix("/")


def source_state(source: Path) -> dict[str, Any]:
    return {
        "commit": git_output(source, "rev-parse", "HEAD"),
        "dirty": bool(git_output(source, "status", "--short")),
        "remote": canonical_repository(
            git_output(source, "remote", "get-url", "origin")
        ),
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


def sql_fragment_files(source: Path) -> list[Path]:
    return sorted((source / "backend" / "skills" / "fragments").glob("*.sql"))


def vendor_override_files(source: Path) -> list[Path]:
    return sorted((source / "backend" / "skills" / "vendors").rglob("*.override.yaml"))


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
        "version": 2,
        "public_skill": PUBLIC_SKILL,
        "excluded_runtime_paths": [
            "backend/skills/_template/",
            "backend/skills/pipelines/_base.skill.yaml",
        ],
        "skills": skills,
        "strategies": strategies,
        "pipeline_docs": pipeline_docs,
        "sql_fragments": {
            path.relative_to(source).as_posix(): {
                "disposition": "exported",
                "destination": (
                    "references/generated/runtime/fragments/" + path.name
                ),
            }
            for path in sql_fragment_files(source)
        },
        "vendor_overrides": {
            path.relative_to(source).as_posix(): {
                "disposition": "exported",
                "application_mode": "advisory_only",
                "destination": (
                    "references/generated/runtime/vendor-overrides/"
                    + path.parent.name
                    + "-"
                    + path.name.removesuffix(".override.yaml")
                    + ".json"
                ),
            }
            for path in vendor_override_files(source)
        },
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
    if policy.get("version") != 2 or policy.get("public_skill") != PUBLIC_SKILL:
        raise ExportError("Unsupported public export policy version or public_skill")
    fixture_source = policy.get("fixture_manifest_source")
    if not isinstance(fixture_source, str) or not (source / fixture_source).is_file():
        raise ExportError("Policy fixture_manifest_source must name an existing file")
    official = policy.get("official_perfetto")
    required_official = {
        "repository",
        "tag",
        "commit",
        "rpc_api_version",
        "stdlib_tree",
        "official_skill_reference",
        "official_skill_role",
    }
    if not isinstance(official, dict) or not required_official.issubset(official):
        raise ExportError("Policy official_perfetto lock is incomplete")

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
        ("sql_fragments", sql_fragment_files(source)),
        ("vendor_overrides", vendor_override_files(source)),
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

    fragment_entries: list[dict[str, Any]] = []
    for relative in sorted(policy["sql_fragments"]):
        config = policy["sql_fragments"][relative]
        if config.get("disposition") != "exported" or not config.get("destination"):
            raise ExportError(f"SQL fragment must be exported: {relative}")
        path = source / relative
        fragment_entries.append(
            {
                "source_path": relative,
                "source_sha256": sha256_file(path),
                "destination": config["destination"],
                "disposition": "exported",
            }
        )

    override_entries: list[dict[str, Any]] = []
    for relative in sorted(policy["vendor_overrides"]):
        config = policy["vendor_overrides"][relative]
        if (
            config.get("disposition") != "exported"
            or config.get("application_mode") != "advisory_only"
            or not config.get("destination")
        ):
            raise ExportError(f"Vendor override must be exported as advisory_only: {relative}")
        path = source / relative
        override_entries.append(
            {
                "source_path": relative,
                "source_sha256": sha256_file(path),
                "destination": config["destination"],
                "disposition": "exported",
                "application_mode": "advisory_only",
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
            "sql_fragments": len(fragment_entries),
            "vendor_overrides": len(override_entries),
        },
        "skills": skill_entries,
        "strategies": strategy_entries,
        "pipeline_docs": pipeline_entries,
        "sql_fragments": fragment_entries,
        "vendor_overrides": override_entries,
        "official_perfetto": policy["official_perfetto"],
        "fixture_manifest_source": policy["fixture_manifest_source"],
    }


def serialize_catalog(catalog: dict[str, Any]) -> str:
    return json.dumps(
        catalog,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n"


def markdown_count_table(
    heading: str,
    first_column: str,
    counts: Counter[str],
) -> str:
    lines = [f"## {heading}", "", f"| {first_column} | Count |", "|---|---:|"]
    lines.extend(f"| `{key}` | {counts[key]} |" for key in sorted(counts))
    return "\n".join(lines) + "\n\n"


def render_migration_coverage(catalog: dict[str, Any]) -> str:
    summary = catalog["summary"]
    runtime_types = Counter(
        {str(key): int(value) for key, value in summary["runtime_types"].items()}
    )
    skill_workflows = Counter(str(entry["workflow"]) for entry in catalog["skills"])
    skill_dispositions = Counter(
        str(entry["disposition"]) for entry in catalog["skills"]
    )
    strategy_dispositions = Counter(
        str(entry["disposition"]) for entry in catalog["strategies"]
    )
    pipeline_dispositions = Counter(
        str(entry["disposition"]) for entry in catalog["pipeline_docs"]
    )
    return (
        "GENERATED FILE - DO NOT EDIT.\n"
        "Generated by `tools/export_from_smartperfetto.py`.\n\n"
        "# SmartPerfetto migration coverage\n\n"
        f"Source repository: `{catalog['source']['repository']}`\n\n"
        f"Source commit: `{catalog['source']['commit']}`\n\n"
        f"Export policy: `{catalog['source']['policy_path']}`\n\n"
        f"Export policy SHA-256: `{catalog['source']['policy_sha256']}`\n\n"
        "## Inventory\n\n"
        "| Source family | Discovered | Publicly exported or merged | Product-only |\n"
        "|---|---:|---:|---:|\n"
        f"| Runtime Skill candidates | {summary['runtime_candidates']} | "
        f"{sum(value for key, value in skill_dispositions.items() if key != 'product-only')} | "
        f"{skill_dispositions.get('product-only', 0)} |\n"
        f"| Strategy and knowledge sources | {summary['strategy_sources']} | "
        f"{summary['exported_strategy_sources']} | {summary['product_only_strategy_sources']} |\n"
        f"| Rendering-pipeline docs | {summary['pipeline_docs']} | "
        f"{sum(value for key, value in pipeline_dispositions.items() if key != 'product-only')} | "
        f"{pipeline_dispositions.get('product-only', 0)} |\n\n"
        f"The source tree also contains {summary['excluded_skill_definitions']} "
        "authoring template/base definitions that are not runtime candidates.\n\n"
        + markdown_count_table("Runtime types", "Runtime type", runtime_types)
        + markdown_count_table("Runtime Skills by workflow", "Workflow", skill_workflows)
        + markdown_count_table(
            "Runtime Skill dispositions", "Disposition", skill_dispositions
        )
        + markdown_count_table(
            "Strategy dispositions", "Disposition", strategy_dispositions
        )
        + "## Boundary\n\n"
        "Exported and merged entries become portable references under the standard Agent Skill. "
        "Product-only strategy sources remain in SmartPerfetto because they depend on provider, "
        "session, artifact, streaming, codebase, or UI orchestration. Every discovered source must "
        "remain explicitly classified by the committed export policy.\n"
    )


def generated_header(entry: dict[str, Any], commit: str, comment: str = "") -> str:
    prefix = f"{comment} " if comment else ""
    return (
        f"{prefix}GENERATED FILE - DO NOT EDIT.\n"
        f"{prefix}Source: {entry['source_path']}\n"
        f"{prefix}Source SHA-256: {entry['source_sha256']}\n"
        f"{prefix}Source commit: {commit}\n"
    )


def write_generated_text(path: Path, content: str) -> None:
    normalized = "\n".join(line.rstrip() for line in content.splitlines()).rstrip()
    write_text_atomic(path, normalized + "\n")


def yaml_block(value: object) -> str:
    rendered = yaml.safe_dump(
        value,
        sort_keys=False,
        allow_unicode=True,
        width=120,
    ).rstrip()
    return f"```yaml\n{rendered}\n```"


def markdown_section(title: str, value: object) -> str:
    if value in (None, {}, []):
        return ""
    return f"## {title}\n\n{yaml_block(value)}\n\n"


def safe_component(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ExportError(f"Missing generated filename component for {label}")
    text = str(value)
    normalized = re.sub(r"[^A-Za-z0-9._-]+", "-", text).strip("-.")
    if not normalized:
        raise ExportError(f"Cannot derive generated filename for {label}: {value!r}")
    return normalized


def destination_in_generated_root(destination: str) -> Path:
    relative = Path(destination)
    try:
        inside = relative.relative_to(GENERATED_PREFIX)
    except ValueError as exc:
        raise ExportError(f"Generated destination is outside {GENERATED_PREFIX}: {destination}") from exc
    if relative.is_absolute() or ".." in relative.parts:
        raise ExportError(f"Unsafe generated destination: {destination}")
    return inside


def infer_step_type(step: dict[str, Any], skill_name: str) -> str:
    step_type = step.get("type")
    if step_type is None:
        if "skill" in step:
            step_type = "skill"
        elif "sql" in step:
            step_type = "atomic"
    if step_type not in SUPPORTED_STEP_TYPES:
        raise ExportError(
            f"Unsupported step type {step_type!r} in {skill_name}.{step.get('id', '<missing>')}"
        )
    return str(step_type)


def render_step(
    step: dict[str, Any],
    skill_name: str,
    source_entry: dict[str, Any],
    commit: str,
    generated_root: Path,
    sql_destinations: set[str],
) -> str:
    step_id = safe_component(step.get("id"), f"{skill_name} step")
    step_type = infer_step_type(step, skill_name)
    title = str(step.get("name") or step_id)
    lines = [f"### {title}", "", f"- ID: `{step_id}`", f"- Type: `{step_type}`"]
    details = {key: value for key, value in step.items() if key not in {"sql", "name"}}
    if "sql" in step:
        sql = step["sql"]
        if not isinstance(sql, str) or not sql.strip():
            raise ExportError(f"Empty SQL in {skill_name}.{step_id}")
        relative = Path("sql") / safe_component(skill_name, "Skill") / f"{step_id}.sql"
        destination_key = relative.as_posix()
        if destination_key in sql_destinations:
            raise ExportError(f"Generated SQL collision: {destination_key}")
        sql_destinations.add(destination_key)
        sql_entry = {
            "source_path": source_entry["source_path"],
            "source_sha256": source_entry["source_sha256"],
        }
        sql_content = generated_header(sql_entry, commit, "--") + "\n" + sql.strip() + "\n"
        write_generated_text(generated_root / relative, sql_content)
        lines.append(f"- SQL: [`../{relative.as_posix()}`](../{relative.as_posix()})")
    lines.extend(["", yaml_block(details), ""])
    return "\n".join(lines)


def render_skill_reference(
    raw: dict[str, Any],
    entry: dict[str, Any],
    commit: str,
    generated_root: Path,
    sql_destinations: set[str],
) -> str:
    name = str(entry["name"])
    meta = raw.get("meta") if isinstance(raw.get("meta"), dict) else {}
    title = str(meta.get("display_name") or raw.get("description") or name).splitlines()[0]
    parts = [generated_header(entry, commit), f"# {title}\n\n"]
    parts.append(
        "This reference is the portable Agent Skill projection of the source definition. "
        "Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array "
        "inputs through `--param`, "
        "load prerequisites through `--module`, and pass non-empty saved rows from prior "
        "steps through `--result`; dotted fields and numeric indexes select saved scalar "
        "values. Evaluate conditions and dependent Skill calls in the "
        "listed order.\n\n"
    )
    overview = {
        key: raw.get(key)
        for key in ("name", "version", "type", "category", "tier", "description", "tags", "optional", "priority")
        if raw.get(key) is not None
    }
    parts.append(markdown_section("Overview", overview))
    for heading, key in (
        ("Metadata", "meta"),
        ("Triggers", "triggers"),
        ("Prerequisites", "prerequisites"),
        ("Inputs", "inputs"),
        ("Identity requirements", "identity"),
        ("Context requirements", "context"),
        ("Module contract", "module"),
        ("Detection", "detection"),
        ("Teaching model", "teaching"),
        ("Analysis guidance", "analysis"),
        ("Dialogue guidance", "dialogue"),
        ("Comparison contract", "comparison"),
    ):
        value = portable_inputs(raw) if key == "inputs" else raw.get(key)
        parts.append(markdown_section(heading, value))

    root_sql = raw.get("sql")
    if root_sql is not None:
        if not isinstance(root_sql, str) or not root_sql.strip():
            raise ExportError(f"Empty root SQL in {name}")
        relative = Path("sql") / safe_component(name, "Skill") / "query.sql"
        destination_key = relative.as_posix()
        if destination_key in sql_destinations:
            raise ExportError(f"Generated SQL collision: {destination_key}")
        sql_destinations.add(destination_key)
        write_generated_text(
            generated_root / relative,
            generated_header(entry, commit, "--") + "\n" + root_sql.strip() + "\n",
        )
        parts.append(
            "## Query\n\n"
            f"Run [`../{relative.as_posix()}`](../{relative.as_posix()}) with the declared inputs.\n\n"
        )

    steps = raw.get("steps")
    if steps is not None:
        if not isinstance(steps, list):
            raise ExportError(f"Steps must be an array in {name}")
        parts.append("## Ordered execution\n\n")
        for step in steps:
            if not isinstance(step, dict):
                raise ExportError(f"Step must be an object in {name}: {step!r}")
            parts.append(
                render_step(
                    step,
                    name,
                    entry,
                    commit,
                    generated_root,
                    sql_destinations,
                )
            )

    for heading, key in (
        ("Output and evidence contract", "output"),
        ("Display metadata", "display"),
        ("Thresholds", "thresholds"),
        ("Diagnostics", "diagnostics"),
        ("Synthesis", "synthesis"),
    ):
        parts.append(markdown_section(heading, raw.get(key)))
    if raw.get("auto_pin"):
        parts.append(
            "## Optional UI metadata\n\n"
            "The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.\n\n"
        )
        parts.append(yaml_block(raw["auto_pin"]) + "\n")
    return "".join(parts).rstrip() + "\n"


_SQL_LIST_PARAMETER = re.compile(
    r"\bIN\s*\(\s*\$\{([A-Za-z_][A-Za-z0-9_]*)(?:\|[^}]*)?\}\s*\)",
    re.IGNORECASE,
)


def portable_inputs(raw: dict[str, Any]) -> object:
    inputs = raw.get("inputs")
    if not isinstance(inputs, list):
        return inputs

    list_parameters: set[str] = set()

    def visit(value: object) -> None:
        if isinstance(value, str):
            list_parameters.update(_SQL_LIST_PARAMETER.findall(value))
        elif isinstance(value, dict):
            for nested in value.values():
                visit(nested)
        elif isinstance(value, list):
            for nested in value:
                visit(nested)

    visit(raw)
    rendered: list[object] = []
    for value in inputs:
        if not isinstance(value, dict) or value.get("name") not in list_parameters:
            rendered.append(value)
            continue
        item = dict(value)
        item["source_type"] = item.get("type")
        item["type"] = "json_array"
        if item.get("description"):
            item["source_description"] = item["description"]
        item["description"] = (
            "Portable binding: pass a JSON array through --param; do not pass a "
            "preformatted SQL list."
        )
        rendered.append(item)
    return rendered


_PLACEHOLDER = re.compile(r"\$\{([^}]+)\}")
_SIGNAL_PATTERN = re.compile(
    r"\b(?:name|track_name|thread_name|process_name)\s+"
    r"(?:GLOB|LIKE|=)\s*'([^']+)'",
    re.IGNORECASE,
)


def write_json(path: Path, value: object) -> None:
    write_text_atomic(
        path,
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    )


def normalize_condition(condition: str) -> str:
    return re.sub(r"\bOR\b", "||", re.sub(r"\bAND\b", "&&", condition, flags=re.I), flags=re.I)


def validate_conditions(value: object, label: str) -> int:
    count = 0
    if isinstance(value, dict):
        for key, nested in value.items():
            if key == "condition" and isinstance(nested, str):
                try:
                    validate_expression(normalize_condition(nested))
                except ValueError as exc:
                    raise ExportError(f"Unsupported condition in {label}: {nested!r}: {exc}") from exc
                count += 1
            count += validate_conditions(nested, label)
    elif isinstance(value, list):
        for nested in value:
            count += validate_conditions(nested, label)
    return count


def expand_sql_fragments(
    sql: str,
    fragment_paths: list[str],
    source: Path,
) -> tuple[str, list[dict[str, Any]]]:
    fragments: list[str] = []
    metadata: list[dict[str, Any]] = []
    for order, relative in enumerate(fragment_paths):
        path = (source / "backend" / "skills" / relative).resolve()
        skills_root = (source / "backend" / "skills").resolve()
        if skills_root not in path.parents or not path.is_file():
            raise ExportError(f"Missing or unsafe SQL fragment: {relative}")
        content = path.read_text(encoding="utf-8").strip()
        fragments.append(content)
        metadata.append(
            {
                "order": order,
                "source_path": path.relative_to(source).as_posix(),
                "source_sha256": sha256_file(path),
            }
        )
    if not fragments:
        return sql.strip(), metadata
    block = ",\n".join(fragments)
    trimmed = sql.lstrip()
    no_comments = re.sub(r"^(?:--[^\n]*\n\s*)*", "", trimmed)
    match = re.match(r"^WITH\s+", no_comments, flags=re.I)
    if match:
        prefix = trimmed[: len(trimmed) - len(no_comments)]
        return f"{prefix}WITH\n{block},\n{no_comments[match.end():]}", metadata
    return f"WITH\n{block}\n{trimmed}", metadata


def query_validation(
    query_id: str,
    fixture_assertions: dict[str, list[dict[str, Any]]],
) -> dict[str, Any]:
    assertions = fixture_assertions.get(query_id, [])
    return {
        "static_valid": True,
        "runtime_compatible": True if assertions else None,
        "execution_verified": bool(assertions),
        "semantic_verified": bool(assertions),
        "fixtures": sorted({str(item["fixture_id"]) for item in assertions}),
        "default_execution": (
            "verified" if assertions else "capability_gate_required"
        ),
    }


def android_query_matrix(
    query_id: str,
    fixture_assertions: dict[str, list[dict[str, Any]]],
) -> dict[str, dict[str, Any]]:
    verified_by_api: dict[int, list[str]] = {}
    for assertion in fixture_assertions.get(query_id, []):
        api = assertion.get("api")
        if isinstance(api, int):
            verified_by_api.setdefault(api, []).append(str(assertion["fixture_id"]))
    return {
        str(api): (
            {"status": "verified", "fixtures": sorted(verified_by_api[api])}
            if api in verified_by_api
            else {
                "status": "capability_gated",
                "reason": "No exact API semantic fixture; runtime capability proof required",
            }
        )
        for api in ANDROID_API_LEVELS
    }


def load_fixture_manifest(source: Path, catalog: dict[str, Any]) -> tuple[dict[str, Any], dict[str, list[dict[str, Any]]]]:
    fixture_source = source / str(catalog["fixture_manifest_source"])
    raw = load_yaml(fixture_source)
    fixtures = raw.get("fixtures")
    if not isinstance(fixtures, list):
        raise ExportError("Fixture manifest fixtures must be an array")
    rendered: list[dict[str, Any]] = []
    assertions: dict[str, list[dict[str, Any]]] = {}
    for fixture in fixtures:
        if not isinstance(fixture, dict) or not isinstance(fixture.get("id"), str):
            raise ExportError("Fixture manifest contains an invalid fixture")
        item = json.loads(json.dumps(fixture))
        source_path = source / str(item["source"])
        if source_path.is_file():
            actual = sha256_file(source_path)
            expected = item.get("sha256")
            if expected and expected != actual:
                raise ExportError(f"Fixture checksum mismatch: {item['id']}")
            item["sha256"] = actual
        checksum_source = item.pop("checksum_source", None)
        if checksum_source:
            checksum_path = source / str(checksum_source)
            if not checksum_path.is_file():
                raise ExportError(f"Fixture checksum source missing: {checksum_source}")
            match = re.search(r"[0-9a-fA-F]{64}", checksum_path.read_text(encoding="utf-8"))
            if not match:
                raise ExportError(f"Fixture checksum source invalid: {checksum_source}")
            item["sha256"] = match.group(0).lower()
            item["checksum_source"] = str(checksum_source)
        if not re.fullmatch(r"[0-9a-f]{64}", str(item.get("sha256", ""))):
            raise ExportError(f"Fixture has no SHA-256: {item['id']}")
        for assertion in item.get("assertions", []):
            query_id = assertion.get("query_id")
            if not isinstance(query_id, str):
                raise ExportError(f"Fixture assertion has no query_id: {item['id']}")
            assertions.setdefault(query_id, []).append(
                {
                    **assertion,
                    "fixture_id": item["id"],
                    "api": item.get("android", {}).get("api"),
                }
            )
        rendered.append(item)
    return (
        {
            "schema_version": 1,
            "source_path": catalog["fixture_manifest_source"],
            "source_sha256": sha256_file(fixture_source),
            "fixtures": rendered,
        },
        assertions,
    )


def git_file_bytes(repository: Path, revision: str, path: str) -> bytes:
    completed = subprocess.run(
        ["git", "show", f"{revision}:{path}"],
        cwd=repository,
        check=False,
        capture_output=True,
    )
    if completed.returncode != 0:
        raise ExportError(f"Cannot read {revision}:{path} from {repository}")
    return completed.stdout


def build_perfetto_source_lock(source: Path, catalog: dict[str, Any]) -> dict[str, Any]:
    policy = dict(catalog["official_perfetto"])
    perfetto = source / "perfetto"
    tag = str(policy["tag"])
    commit = git_output(perfetto, "rev-parse", f"{tag}^{{}}")
    if commit != policy["commit"]:
        raise ExportError(f"Canonical Perfetto tag mismatch: {tag} -> {commit}")
    stdlib_path = "src/trace_processor/perfetto_sql/stdlib"
    stdlib_tree = git_output(perfetto, "rev-parse", f"{tag}:{stdlib_path}")
    if stdlib_tree != policy["stdlib_tree"]:
        raise ExportError(f"Canonical Perfetto stdlib tree mismatch: {stdlib_tree}")
    official_path = str(policy["official_skill_reference"])
    official_bytes = git_file_bytes(perfetto, tag, official_path)
    lock_path = SKILL_ROOT / "references" / "trace-processor-lock.json"
    binary_lock = json.loads(lock_path.read_text(encoding="utf-8"))
    if binary_lock.get("perfetto_version") != tag:
        raise ExportError("Trace processor artifact lock does not match official tag")
    symbol_path = source / "backend" / "data" / "perfettoStdlibSymbols.json"
    docs_path = source / "backend" / "data" / "perfettoSqlDocs.json"
    return {
        "schema_version": 1,
        "repository": policy["repository"],
        "release": {
            "tag": tag,
            "commit": commit,
            "rpc_api_version": policy["rpc_api_version"],
            "stdlib_tree": stdlib_tree,
        },
        "runtime_substrate": {
            "trace_processor_lock": "../../../trace-processor-lock.json",
            "trace_processor_lock_sha256": sha256_file(lock_path),
            "platforms": binary_lock["platforms"],
            "required_runtime_checks": ["artifact_sha256", "version_commit", "rpc_api_version"],
        },
        "generated_indexes": {
            "stdlib_symbols_sha256": sha256_file(symbol_path),
            "stdlib_docs_sha256": sha256_file(docs_path),
        },
        "official_skill_reference": {
            "role": policy["official_skill_role"],
            "path": official_path,
            "tag": tag,
            "sha256": hashlib.sha256(official_bytes).hexdigest(),
            "runtime_dependency": False,
        },
        "canary": {
            "tag": policy.get("latest_canary_tag"),
            "commit": policy.get("latest_canary_commit"),
            "release_blocking": False,
            "stdlib_tree_matches_release": True,
        },
    }


def persistent_objects(sql: str) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    created = [
        {"kind": match.group("kind").lower(), "name": match.group("name")}
        for match in PERSISTENT_OBJECT.finditer(sql)
    ]
    dropped = [
        {"kind": match.group("kind").lower(), "name": match.group("name")}
        for match in DROP_OBJECT.finditer(sql)
    ]
    return created, dropped


def query_parameters(sql: str, input_names: set[str], result_names: set[str]) -> tuple[list[str], list[str]]:
    parameters: set[str] = set()
    results: set[str] = set()
    for expression in _PLACEHOLDER.findall(sql):
        root = re.split(r"[.|\[]", expression.partition("|")[0], maxsplit=1)[0]
        if root in result_names:
            results.add(root)
        elif root in input_names or root == "item":
            parameters.add(root)
        else:
            parameters.add(root)
    return sorted(parameters), sorted(results)


def android_adapters(modules: list[str], sql_text: str) -> list[dict[str, Any]]:
    adapters: list[dict[str, Any]] = []
    joined = " ".join(modules) + " " + sql_text
    if "android.startup" in joined:
        adapters.append(
            {
                "id": "official_android_startup_tags",
                "branches": ["api<=28", "api29-32", "api>=33"],
                "source": "perfetto stdlib android/startup/startups.sql",
            }
        )
    if "frame_timeline" in joined or "android.frames" in joined:
        adapters.append(
            {
                "id": "official_frame_timeline_or_legacy",
                "version_hint": {"frame_timeline_min_api": 31},
                "selection": "actual rows first; legacy Choreographer/DrawFrame fallback",
                "source": "perfetto stdlib android/frames/timeline.sql",
            }
        )
    if "android_input" in joined or "android.input" in joined:
        adapters.append(
            {
                "id": "android_input_source",
                "version_hint": {"proto_input_min_api_hint": 34},
                "selection": "data-source descriptor, build type, config, then rows",
            }
        )
    if any(token in joined for token in ("sched", "ftrace", "irq", "cpu_frequency")):
        adapters.append(
            {
                "id": "kernel_tracepoints",
                "selection": "available events, trace config/setup errors, schema, then rows",
            }
        )
    return adapters


def probe_capabilities(
    query_id: str,
    required_tables: list[str],
) -> list[str]:
    lowered_id = query_id.lower()
    lowered_tables = {table.lower() for table in required_tables}
    capabilities: set[str] = set()
    if "gpu" in lowered_id or "mali" in lowered_id or any("gpu" in table for table in lowered_tables):
        capabilities.add("gpu")
    if any("heap_graph" in table for table in lowered_tables) or "heap_graph" in lowered_id:
        capabilities.add("heap_graph")
    table_mapping = {
        "slice": "slices",
        "thread_state": "thread_states",
        "sched": "scheduling",
        "counter": "counters",
        "counter_track": "counters",
        "actual_frame_timeline_slice": "frame_timeline",
        "expected_frame_timeline_slice": "frame_timeline",
        "args": "arguments",
    }
    for table, capability in table_mapping.items():
        if table in lowered_tables:
            capabilities.add(capability)
    return sorted(capabilities)


def normalize_step(
    step: dict[str, Any],
    skill_id: str,
    source: Path,
    generated_root: Path,
    source_entry: dict[str, Any],
    commit: str,
    modules: list[str],
    input_names: set[str],
    result_names: set[str],
    setup_queries: list[str],
    fixture_assertions: dict[str, list[dict[str, Any]]],
    object_producers: dict[str, str],
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    step_id = safe_component(step.get("id"), f"{skill_id} step")
    step_type = infer_step_type(step, skill_id)
    kept = {
        key: value
        for key, value in step.items()
        if key
        in {
            "id", "name", "description", "optional", "on_empty", "condition",
            "save_as", "skill", "params", "source", "item_skill", "item_params",
            "max_items", "filter", "inputs", "rules", "ai_assist", "fallback",
            "prompt", "for_each",
        }
    }
    kept["type"] = step_type
    if isinstance(kept.get("condition"), str):
        kept["condition"] = normalize_condition(str(kept["condition"]))
    validate_conditions(kept, f"{skill_id}.{step_id}")
    if "sql" not in step:
        return kept, None
    fragment_paths = [str(value) for value in step.get("sql_fragments", []) or []]
    expanded, fragment_metadata = expand_sql_fragments(str(step["sql"]), fragment_paths, source)
    relative = Path("sql") / safe_component(skill_id, "Skill") / f"{step_id}.sql"
    write_generated_text(
        generated_root / relative,
        generated_header(source_entry, commit, "--") + "\n" + expanded + "\n",
    )
    query_id = f"{skill_id}/{step_id}"
    kept["query_id"] = query_id
    created, dropped = persistent_objects(expanded)
    created_names = {item["name"] for item in created}
    required_objects = sorted(
        name
        for name in object_producers
        if name not in created_names and re.search(rf"\b{re.escape(name)}\b", expanded)
    )
    dependency_setups = [object_producers[name] for name in required_objects]
    parameters, results = query_parameters(expanded, input_names, result_names)
    kept["result_dependencies"] = results
    query = {
        "id": query_id,
        "skill_id": skill_id,
        "step_id": step_id,
        "path": relative.as_posix(),
        "sha256": sha256_file(generated_root / relative),
        "source": {
            "repository": "https://github.com/Gracker/SmartPerfetto",
            "commit": commit,
            "path": source_entry["source_path"],
            "sha256": source_entry["source_sha256"],
        },
        "template": {
            "parameters": parameters,
            "result_dependencies": results,
            "fragments": fragment_metadata,
        },
        "sql_dependencies": {
            "declared_modules": modules,
            "required_tables": [],
            "creates": created,
            "drops": dropped,
            "requires": required_objects,
            "setup_queries": list(dict.fromkeys([*setup_queries, *dependency_setups])),
        },
        "signal_patterns": sorted(set(_SIGNAL_PATTERN.findall(expanded))),
        "compatibility": {
            "android": android_query_matrix(query_id, fixture_assertions),
            "probe_capabilities": probe_capabilities(query_id, []),
        },
        "validation": query_validation(query_id, fixture_assertions),
        "license": {"origin": "smartperfetto", "spdx": "AGPL-3.0-or-later"},
    }
    if created:
        setup_queries.append(query_id)
    return kept, query


def build_runtime_assets(
    source: Path,
    catalog: dict[str, Any],
    generated_root: Path,
) -> dict[str, int]:
    runtime_root = generated_root / "runtime"
    fixture_manifest, fixture_assertions = load_fixture_manifest(source, catalog)
    write_json(runtime_root / "fixture-manifest.json", fixture_manifest)
    source_lock = build_perfetto_source_lock(source, catalog)
    write_json(runtime_root / "perfetto-source-lock.json", source_lock)

    symbol_source = source / "backend" / "data" / "perfettoStdlibSymbols.json"
    symbol_index = json.loads(symbol_source.read_text(encoding="utf-8"))
    stdlib_prefix = "src/trace_processor/perfetto_sql/stdlib/"
    official_modules = {
        path.removeprefix(stdlib_prefix).removesuffix(".sql").replace("/", ".")
        for path in git_output(
            source / "perfetto",
            "ls-tree",
            "-r",
            "--name-only",
            str(source_lock["release"]["tag"]),
            stdlib_prefix.rstrip("/"),
        ).splitlines()
        if path.endswith(".sql")
    }
    write_json(
        runtime_root / "stdlib-symbols.json",
        {
            **symbol_index,
            "source_sha256": sha256_file(symbol_source),
            "official_tag": source_lock["release"]["tag"],
            "official_stdlib_tree": source_lock["release"]["stdlib_tree"],
        },
    )

    skills_index: dict[str, str] = {}
    sql_shards: list[str] = []
    android_index: dict[str, str] = {}
    runtime_counts: Counter[str] = Counter()
    total_queries = 0
    total_steps = 0
    total_conditions = 0
    total_step_conditions = 0
    execution_verified_queries: list[str] = []
    semantic_verified_queries: list[str] = []
    commit = str(catalog["source"]["commit"])
    object_producers: dict[str, str] = {}
    for source_entry in catalog["skills"]:
        producer_skill_id = str(source_entry["name"])
        producer_raw = load_yaml(source / source_entry["source_path"])
        root_sql = producer_raw.get("sql")
        if isinstance(root_sql, str):
            for created, _dropped in [persistent_objects(root_sql)]:
                for item in created:
                    object_producers.setdefault(item["name"], f"{producer_skill_id}/root")
        for producer_step in producer_raw.get("steps", []) or []:
            if not isinstance(producer_step, dict) or not isinstance(producer_step.get("sql"), str):
                continue
            producer_step_id = safe_component(
                producer_step.get("id"), f"{producer_skill_id} step"
            )
            created, _dropped = persistent_objects(str(producer_step["sql"]))
            for item in created:
                object_producers.setdefault(
                    item["name"], f"{producer_skill_id}/{producer_step_id}"
                )
    for entry in catalog["skills"]:
        skill_id = str(entry["name"])
        raw = load_yaml(source / entry["source_path"])
        skill_type = str(raw.get("type", "unknown"))
        runtime_status = (
            "knowledge_only"
            if skill_type in {"pipeline_definition", "comparison"}
            else "executable"
        )
        runtime_counts[runtime_status] += 1
        modules = [str(value) for value in raw.get("prerequisites", {}).get("modules", []) or []]
        unknown_modules = sorted(set(modules) - official_modules)
        if unknown_modules:
            raise ExportError(f"Unknown official modules in {skill_id}: {unknown_modules}")
        inputs = portable_inputs(raw)
        input_list = inputs if isinstance(inputs, list) else []
        input_names = {
            str(value["name"])
            for value in input_list
            if isinstance(value, dict) and isinstance(value.get("name"), str)
        }
        raw_steps = raw.get("steps", []) or []
        if not isinstance(raw_steps, list):
            raise ExportError(f"Steps must be an array in {skill_id}")
        result_names = {
            str(step.get("id"))
            for step in raw_steps
            if isinstance(step, dict) and step.get("id")
        } | {
            str(step.get("save_as"))
            for step in raw_steps
            if isinstance(step, dict) and step.get("save_as")
        }
        queries: list[dict[str, Any]] = []
        normalized_steps: list[dict[str, Any]] = []
        setup_queries: list[str] = []
        root_query_id: str | None = None
        root_sql = raw.get("sql")
        if isinstance(root_sql, str) and root_sql.strip():
            root_step = {"id": "root", "type": "atomic", "sql": root_sql}
            normalized_root, query = normalize_step(
                root_step, skill_id, source, generated_root, entry, commit, modules,
                input_names, result_names, setup_queries, fixture_assertions,
                object_producers,
            )
            root_query_id = normalized_root["query_id"]
            assert query is not None
            query["path"] = query["path"].replace("/root.sql", "/query.sql")
            old = generated_root / "sql" / safe_component(skill_id, "Skill") / "root.sql"
            expected = generated_root / "sql" / safe_component(skill_id, "Skill") / "query.sql"
            if old.exists():
                os.replace(old, expected)
                query["sha256"] = sha256_file(expected)
            queries.append(query)
        for raw_step in raw_steps:
            if not isinstance(raw_step, dict):
                raise ExportError(f"Step must be an object in {skill_id}")
            normalized, query = normalize_step(
                raw_step, skill_id, source, generated_root, entry, commit, modules,
                input_names, result_names, setup_queries, fixture_assertions,
                object_producers,
            )
            normalized_steps.append(normalized)
            if query:
                query["sql_dependencies"]["required_tables"] = [
                    str(value)
                    for value in raw.get("prerequisites", {}).get("required_tables", []) or []
                ]
                queries.append(query)
        skill_required_tables = [
            str(value)
            for value in raw.get("prerequisites", {}).get("required_tables", []) or []
        ]
        for query in queries:
            query["sql_dependencies"]["required_tables"] = skill_required_tables
            query["compatibility"]["probe_capabilities"] = probe_capabilities(
                str(query["id"]), skill_required_tables
            )
        condition_count = validate_conditions(raw_steps, skill_id)
        total_conditions += condition_count
        total_step_conditions += sum(
            1
            for step in raw_steps
            if isinstance(step, dict) and isinstance(step.get("condition"), str)
        )
        total_steps += len(raw_steps)
        sql_text = "\n".join(
            str(step.get("sql", "")) for step in raw_steps if isinstance(step, dict)
        ) + (str(root_sql) if isinstance(root_sql, str) else "")
        adapters = android_adapters(modules, sql_text)
        required_tables = skill_required_tables
        skill_manifest = {
            "schema_version": 1,
            "id": skill_id,
            "version": str(raw.get("version", "1.0")),
            "type": skill_type,
            "runtime_status": runtime_status,
            "workflow": entry.get("workflow"),
            "source": {
                "path": entry["source_path"],
                "sha256": entry["source_sha256"],
                "commit": commit,
            },
            "inputs": input_list,
            "prerequisites": {"modules": modules, "required_tables": required_tables},
            "identity": raw.get("identity", {"policy": "none"}),
            "steps": normalized_steps,
            "query_id": root_query_id,
            "android": {
                "adapters": adapters,
                "selection_order": [
                    "device_capability", "trace_config_and_setup_errors",
                    "engine_module_and_schema", "target_range_row_coverage",
                    "api_hint",
                ],
                "signal_patterns": sorted(set(_SIGNAL_PATTERN.findall(sql_text))),
            },
        }
        skill_relative = f"skills/{safe_component(skill_id, 'Skill')}.json"
        write_json(runtime_root / skill_relative, skill_manifest)
        skills_index[skill_id] = skill_relative

        query_relative = f"queries/{safe_component(skill_id, 'Skill')}.json"
        write_json(
            runtime_root / query_relative,
            {"schema_version": 1, "skill_id": skill_id, "queries": queries},
        )
        sql_shards.append(query_relative)
        total_queries += len(queries)
        execution_verified_queries.extend(
            query["id"] for query in queries if query["validation"]["execution_verified"]
        )
        semantic_verified_queries.extend(
            query["id"] for query in queries if query["validation"]["semantic_verified"]
        )

        status = "not_applicable" if runtime_status == "knowledge_only" else "capability_gated"
        query_by_id = {str(query["id"]): query for query in queries}
        android_manifest = {
            "schema_version": 1,
            "skill_id": skill_id,
            "selection_order": skill_manifest["android"]["selection_order"],
            "adapters": adapters,
            "required_modules": modules,
            "required_tables": required_tables,
            "signal_patterns": skill_manifest["android"]["signal_patterns"],
            "api": {
                str(api): {
                    "status": status,
                    "reason": (
                        "Metadata/reference Skill has no trace execution"
                        if status == "not_applicable"
                        else "Runtime capabilities are authoritative; no full-Skill exact API fixture"
                    ),
                }
                for api in ANDROID_API_LEVELS
            },
            "steps": {
                str(step["id"]): {
                    "query_id": step.get("query_id"),
                    "api": (
                        query_by_id[str(step["query_id"])]["compatibility"]["android"]
                        if step.get("query_id") in query_by_id
                        else {
                            str(api): {"status": status} for api in ANDROID_API_LEVELS
                        }
                    ),
                }
                for step in normalized_steps
            },
        }
        android_relative = f"android/{safe_component(skill_id, 'Skill')}.json"
        write_json(runtime_root / android_relative, android_manifest)
        android_index[skill_id] = android_relative

    write_json(
        runtime_root / "skill-index.json",
        {
            "schema_version": 1,
            "source_commit": commit,
            "summary": {
                "skills": len(skills_index),
                "executable": runtime_counts["executable"],
                "knowledge_only": runtime_counts["knowledge_only"],
                "steps": total_steps,
                "conditions": total_conditions,
                "step_conditions": total_step_conditions,
            },
            "skills": skills_index,
        },
    )
    write_json(
        runtime_root / "sql-index.json",
        {
            "schema_version": 1,
            "source_commit": commit,
            "summary": {"queries": total_queries, "shards": len(sql_shards)},
            "shards": sorted(sql_shards),
        },
    )
    write_json(
        runtime_root / "sql-validation-report.json",
        {
            "schema_version": 1,
            "source_commit": commit,
            "perfetto": source_lock["release"],
            "summary": {
                "queries": total_queries,
                "static_valid": total_queries,
                "execution_verified": len(execution_verified_queries),
                "semantic_verified": len(semantic_verified_queries),
                "capability_gated": total_queries - len(semantic_verified_queries),
            },
            "execution_verified_queries": sorted(execution_verified_queries),
            "semantic_verified_queries": sorted(semantic_verified_queries),
            "policy": {
                "static_valid_is_not_semantic_proof": True,
                "capability_gated_queries_may_not_support_causal_claims": True,
                "unknown_or_unsupported_requires_explicit_override": True,
            },
        },
    )
    write_json(
        runtime_root / "android-index.json",
        {
            "schema_version": 1,
            "api_levels": list(ANDROID_API_LEVELS),
            "capability_states": list(CAPABILITY_STATES),
            "compatibility_statuses": ["verified", "capability_gated", "unsupported", "unknown", "not_applicable"],
            "skills": android_index,
        },
    )

    strategies = []
    for entry in catalog["strategies"]:
        disposition = entry["disposition"]
        strategies.append(
            {
                "source_path": entry["source_path"],
                "source_sha256": entry["source_sha256"],
                "workflow": entry.get("workflow"),
                "destination": entry.get("destination"),
                "status": (
                    "product_only"
                    if disposition == "product-only"
                    else "portable_transformed"
                ),
                "replacement": (
                    entry.get("reason")
                    if disposition == "product-only"
                    else "manifest-backed Skill/query/evidence operations"
                ),
            }
        )
    write_json(
        runtime_root / "strategy-index.json",
        {
            "schema_version": 1,
            "summary": {"sources": len(strategies)},
            "strategies": strategies,
        },
    )

    for entry in catalog["sql_fragments"]:
        source_path = source / entry["source_path"]
        write_generated_text(
            generated_root / destination_in_generated_root(entry["destination"]),
            generated_header(entry, commit, "--") + "\n" + source_path.read_text(encoding="utf-8"),
        )
    for entry in catalog["vendor_overrides"]:
        raw = load_yaml(source / entry["source_path"])
        write_json(
            generated_root / destination_in_generated_root(entry["destination"]),
            {
                "schema_version": 1,
                "application_mode": "advisory_only",
                "source": {
                    "path": entry["source_path"],
                    "sha256": entry["source_sha256"],
                    "commit": commit,
                },
                "definition": raw,
            },
        )
    return {
        "runtime_skills": len(skills_index),
        "runtime_queries": total_queries,
        "runtime_conditions": total_conditions,
    }


def render_comparison_reference(entry: dict[str, Any], commit: str) -> str:
    return (
        generated_header(entry, commit)
        + "\n# File-based trace comparison\n\n"
        + "The SmartPerfetto source definition uses product snapshot services. The portable "
        "projection replaces that boundary with local JSON files and "
        "`scripts/perfetto_compare.py`.\n\n"
        + "## Inputs\n\n"
        + "Analyze every trace independently, then write one side summary that follows "
        "`assets/comparison-input-schema.json`. Each metric carries status, numeric value "
        "when observed, unit, exact definition, and evidence references.\n\n"
        + "## Execution\n\n"
        + "```bash\n"
        + "python3 <skill-root>/scripts/perfetto_compare.py \\\n"
        + "  --side baseline=/absolute/baseline.json \\\n"
        + "  --side candidate=/absolute/candidate.json \\\n"
        + "  --baseline baseline --output /absolute/comparison.json\n"
        + "```\n\n"
        + "The adapter rejects duplicate sides and incompatible definitions, records missing "
        "metrics as limitations, and computes absolute/percent deltas only for comparable facts.\n"
    )


def strip_frontmatter(content: str) -> tuple[str, int]:
    lines = content.splitlines()
    starts = [index for index, line in enumerate(lines[:10]) if line.strip() == "---"]
    for start in starts:
        for end in range(start + 1, len(lines)):
            if lines[end].strip() != "---":
                continue
            candidate = "\n".join(lines[start + 1 : end])
            try:
                parsed = yaml.safe_load(candidate)
            except yaml.YAMLError:
                continue
            if isinstance(parsed, dict):
                return "\n".join(lines[end + 1 :]).lstrip() + "\n", end + 1
    return content, 0


def strategy_frontmatter(content: str) -> tuple[dict[str, Any] | None, str]:
    body, removed_lines = strip_frontmatter(content)
    if not removed_lines:
        return None, body
    lines = content.splitlines()
    start = next(index for index, line in enumerate(lines[:10]) if line.strip() == "---")
    end = removed_lines - 1
    parsed = yaml.safe_load("\n".join(lines[start + 1 : end]))
    return (parsed if isinstance(parsed, dict) else None), body


_PRODUCT_RUNTIME_TOKENS = (
    "execute_sql_on", "submit_plan", "invoke_skill", "fetch_artifact",
    "create_artifact", "get_artifact", "load_artifact", "navigate_timeline",
    "pin_tracks", "list_skills", "analysis_result_snapshot",
    "get_comparison_context", "compare_skill", "perfetto_query_by_trace_side",
    "referenceTraceId", "tracePairContext", "AnalysisResultSnapshot",
    "snapshot_ids", "baseline_snapshot_id", "perfetto_skill_run",
    "read_evidence_bundle", "write_evidence_bundle", "portable_checklist",
    "update_plan_phase", "lookup_strategy_detail",
    "lookup_knowledge", "submit_hypothesis", "resolve_hypothesis",
    "flag_uncertainty", "write_analysis_note", "detect_architecture",
    "lookup_sql_schema", "process_identity_resolver",
)


def contains_product_runtime(value: str) -> bool:
    return any(token.lower() in value.lower() for token in _PRODUCT_RUNTIME_TOKENS)


def sanitize_strategy_metadata(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: sanitized
            for key, nested in value.items()
            if not contains_product_runtime(str(key))
            and (sanitized := sanitize_strategy_metadata(nested)) is not None
        }
    if isinstance(value, list):
        return [
            sanitized
            for nested in value
            if (sanitized := sanitize_strategy_metadata(nested)) is not None
        ]
    if isinstance(value, str) and contains_product_runtime(value):
        return None
    return value


def strip_product_runtime_content(body: str) -> tuple[str, int]:
    kept: list[str] = []
    removed = 0
    lines = body.splitlines()
    index = 0
    while index < len(lines):
        if lines[index].lstrip().startswith("```"):
            block = [lines[index]]
            index += 1
            while index < len(lines):
                block.append(lines[index])
                if lines[index].lstrip().startswith("```"):
                    index += 1
                    break
                index += 1
            if contains_product_runtime("\n".join(block)):
                removed += len(block)
            else:
                kept.extend(block)
            continue
        kept.append(lines[index])
        index += 1
    portable: list[str] = []
    for paragraph in "\n".join(kept).split("\n\n"):
        if contains_product_runtime(paragraph):
            removed += len(paragraph.splitlines())
        else:
            portable.append(paragraph)
    return "\n\n".join(portable), removed


def portable_strategy_content(
    content: str,
) -> tuple[str, list[dict[str, Any]], dict[str, Any] | None]:
    metadata, body = strategy_frontmatter(content)
    transformations: list[dict[str, Any]] = []
    body, removed_lines = strip_product_runtime_content(body)
    body, host_count = re.subn(
        r"\bSmartPerfetto(?:\s+UI)?\b", "the portable runtime", body, flags=re.I
    )
    if removed_lines or host_count:
        transformations.append(
            {
                "reason": "product runtime actions removed; concrete CLI contract added",
                "removed_lines": removed_lines,
                "replacements": host_count,
            }
        )
    return body.strip() + "\n", transformations, sanitize_strategy_metadata(metadata)


def render_strategy_reference(
    source: Path,
    entry: dict[str, Any],
    commit: str,
) -> tuple[str, list[dict[str, Any]]]:
    content = source.read_text(encoding="utf-8")
    portable, transformations, metadata = portable_strategy_content(content)
    title = source.name.removesuffix(".md").replace(".", " ").replace("-", " ").title()
    if source.suffix in {".yaml", ".yml"}:
        portable = f"```yaml\n{portable.rstrip()}\n```\n"
    metadata_block = yaml_block(metadata) if metadata else ""
    rendered = (
        generated_header(entry, commit)
        + f"\n# {title}\n\n"
        + "Portable methodology extracted from the SmartPerfetto strategy library.\n\n"
        + "`execute_sql(...)` examples mean to run the contained SQL through "
        "`perfetto_query.py`; they do not require a product tool.\n\n"
        + "## Portable execution commands\n\n"
        + "- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.\n"
        + "- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.\n"
        + "- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.\n"
        + "- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.\n"
        + "- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.\n\n"
        + (
            "## Portable strategy metadata\n\n"
            + metadata_block
            + "\n\n"
            if metadata
            else ""
        )
        + portable
    )
    return rendered, transformations


def render_pipeline_doc(source: Path, entry: dict[str, Any], commit: str) -> str:
    content, _ = strip_frontmatter(source.read_text(encoding="utf-8"))
    return generated_header(entry, commit) + "\n" + content.lstrip()


def directory_manifest(root: Path) -> dict[str, str]:
    if not root.is_dir():
        return {}
    return {
        path.relative_to(root).as_posix(): sha256_file(path)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def generate_references(
    source: Path,
    catalog: dict[str, Any],
    *,
    check: bool,
) -> None:
    references_root = SKILL_ROOT / "references"
    generated = references_root / "generated"
    references_root.mkdir(parents=True, exist_ok=True)
    transformations: list[dict[str, Any]] = []
    sql_destinations: set[str] = set()
    with tempfile.TemporaryDirectory(prefix=".generated-", dir=references_root) as temp:
        temporary_generated = Path(temp)
        commit = str(catalog["source"]["commit"])
        for entry in catalog["skills"]:
            if entry["disposition"] not in {"exported", "merged"}:
                continue
            if entry["name"] == "multi_trace_result_comparison":
                content = render_comparison_reference(entry, commit)
                transformations.append(
                    {
                        "source_path": entry["source_path"],
                        "reason": "product snapshot comparison replaced by file-based JSON adapter",
                        "removed_lines": 0,
                    }
                )
            else:
                raw = load_yaml(source / entry["source_path"])
                content = render_skill_reference(
                    raw,
                    entry,
                    commit,
                    temporary_generated,
                    sql_destinations,
                )
            write_generated_text(
                temporary_generated / destination_in_generated_root(entry["destination"]),
                content,
            )
        for entry in catalog["strategies"]:
            if entry["disposition"] not in {"exported", "merged"}:
                continue
            content, changes = render_strategy_reference(
                source / entry["source_path"], entry, commit
            )
            write_generated_text(
                temporary_generated / destination_in_generated_root(entry["destination"]),
                content,
            )
            for change in changes:
                transformations.append({"source_path": entry["source_path"], **change})
        for entry in catalog["pipeline_docs"]:
            content = render_pipeline_doc(source / entry["source_path"], entry, commit)
            write_generated_text(
                temporary_generated / destination_in_generated_root(entry["destination"]),
                content,
            )
        runtime_summary = build_runtime_assets(source, catalog, temporary_generated)
        generated_catalog = {
            "schema_version": 2,
            "source_commit": commit,
            "source_catalog_sha256": hashlib.sha256(
                serialize_catalog(catalog).encode("utf-8")
            ).hexdigest(),
            "generated_files": len(directory_manifest(temporary_generated)) + 1,
            "sql_files": len(sql_destinations),
            **runtime_summary,
            "transformations": sorted(
                transformations,
                key=lambda item: (item["source_path"], item["reason"]),
            ),
        }
        write_text_atomic(
            temporary_generated / "catalog.json",
            json.dumps(generated_catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        )
        expected = directory_manifest(temporary_generated)
        if check:
            current = directory_manifest(generated)
            if current != expected:
                missing = sorted(set(expected) - set(current))
                extra = sorted(set(current) - set(expected))
                changed = sorted(
                    path for path in set(current) & set(expected) if current[path] != expected[path]
                )
                raise ExportError(
                    "Generated reference drift detected: "
                    f"missing={missing[:5]}, extra={extra[:5]}, changed={changed[:5]}"
                )
            return
        if generated.exists():
            shutil.rmtree(generated)
        os.replace(temporary_generated, generated)


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
        expected_migration = render_migration_coverage(catalog)
        if not MIGRATION_COVERAGE.is_file():
            raise ExportError(f"Migration coverage is missing: {MIGRATION_COVERAGE}")
        if MIGRATION_COVERAGE.read_text(encoding="utf-8") != expected_migration:
            raise ExportError(
                f"Migration coverage drift detected: run {Path(__file__).name} --source {source}"
            )
        generate_references(source, catalog, check=True)
        print(f"Catalog is current: {output}")
        return 0
    write_text_atomic(output, serialized)
    write_text_atomic(MIGRATION_COVERAGE, render_migration_coverage(catalog))
    generate_references(source, catalog, check=False)
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
