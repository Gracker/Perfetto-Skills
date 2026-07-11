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
SUPPORTED_STEP_TYPES = {
    "atomic",
    "skill",
    "diagnostic",
    "iterator",
    "ai_summary",
}
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


def portable_strategy_content(content: str) -> tuple[str, list[dict[str, Any]]]:
    content, frontmatter_lines = strip_frontmatter(content)
    transformations: list[dict[str, Any]] = []
    if frontmatter_lines:
        transformations.append(
            {"reason": "non-portable frontmatter", "removed_lines": frontmatter_lines}
        )
    blocks = re.split(r"(\n\s*\n)", content)
    kept: list[str] = []
    removed_lines = 0
    for block in blocks:
        if PRODUCT_RUNTIME_PATTERN.search(block):
            removed_lines += len(block.splitlines())
        else:
            kept.append(block)
    if removed_lines:
        transformations.append(
            {"reason": "SmartPerfetto runtime or UI instruction", "removed_lines": removed_lines}
        )
    return "".join(kept).strip() + "\n", transformations


def render_strategy_reference(
    source: Path,
    entry: dict[str, Any],
    commit: str,
) -> tuple[str, list[dict[str, Any]]]:
    content = source.read_text(encoding="utf-8")
    portable, transformations = portable_strategy_content(content)
    title = source.name.removesuffix(".md").replace(".", " ").replace("-", " ").title()
    if source.suffix in {".yaml", ".yml"}:
        portable = f"```yaml\n{portable.rstrip()}\n```\n"
    rendered = (
        generated_header(entry, commit)
        + f"\n# {title}\n\n"
        + "Portable methodology extracted from the SmartPerfetto strategy library.\n\n"
        + "`execute_sql(...)` examples mean to run the contained SQL through "
        "`perfetto_query.py`; they do not require a product tool.\n\n"
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
        generated_catalog = {
            "schema_version": 1,
            "source_commit": commit,
            "source_catalog_sha256": hashlib.sha256(
                serialize_catalog(catalog).encode("utf-8")
            ).hexdigest(),
            "generated_files": len(directory_manifest(temporary_generated)) + 1,
            "sql_files": len(sql_destinations),
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
