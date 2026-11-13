"""Project product teaching cards into a self-contained public reference."""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
import hashlib
from pathlib import Path, PurePosixPath
import re
from typing import Any

import yaml


SOURCE_PATH = "backend/skills/pipelines/index.yaml"
DESTINATION = "references/generated/knowledge/rendering-teaching.md"
_PRODUCT_PATHS = {"skills/pipelines/index.yaml", SOURCE_PATH}
_IDENTIFIER = re.compile(r"^[A-Z][A-Z0-9_]*$")
_REFERENCE = re.compile(
    r"(?P<path>(?:backend/)?skills/pipelines/index\.yaml)"
    r"(?:#(?P<fragment>[A-Za-z0-9_.-]*))?"
)


class PipelineTeachingError(ValueError):
    """The teaching dependency cannot be safely projected."""


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _identifier(value: object) -> bool:
    return isinstance(value, str) and _IDENTIFIER.fullmatch(value) is not None


def _safe_relative(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and path.as_posix() == value


def _read_yaml(source: Path, relative: str) -> tuple[dict[str, Any], str]:
    if not _safe_relative(relative):
        raise PipelineTeachingError("Teaching source path must be a safe relative path")
    target = source / relative
    if not target.resolve().is_relative_to(source) or not target.is_file():
        raise PipelineTeachingError(f"Teaching source is missing or outside its boundary: {relative}")
    current = target
    while current != source:
        if current.is_symlink():
            raise PipelineTeachingError(f"Teaching source must not use a symlink: {relative}")
        current = current.parent
    content = target.read_bytes()
    try:
        value = yaml.safe_load(content)
    except yaml.YAMLError as error:
        raise PipelineTeachingError(f"Invalid teaching YAML: {relative}") from error
    if not isinstance(value, dict):
        raise PipelineTeachingError(f"Teaching YAML must be a mapping: {relative}")
    return value, hashlib.sha256(content).hexdigest()


def _reference_id(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    path, separator, fragment = value.partition("#")
    if path not in _PRODUCT_PATHS or not separator:
        return None
    prefix = "rendering_types."
    identifier = fragment.removeprefix(prefix)
    if not fragment.startswith(prefix) or not _identifier(identifier):
        return None
    return identifier


def _validate_card(type_id: str, value: object) -> dict[str, Any]:
    if not _identifier(type_id) or not isinstance(value, dict):
        raise PipelineTeachingError("Rendering type must have a safe ID and mapping")
    if set(value) != {"kind", "teaching"} or value["kind"] not in ("overview", "concrete"):
        raise PipelineTeachingError(f"Invalid rendering type: {type_id}")
    card = value["teaching"]
    keys = {"title", "summary", "mermaidBlocks", "threadRoles", "keySlices"}
    if not isinstance(card, dict) or set(card) != keys:
        raise PipelineTeachingError(f"Invalid teaching card fields: {type_id}")
    if not _text(card["title"]) or not _text(card["summary"]):
        raise PipelineTeachingError(f"Invalid teaching title or summary: {type_id}")
    for key in ("mermaidBlocks", "keySlices"):
        if not isinstance(card[key], list) or not all(_text(item) for item in card[key]):
            raise PipelineTeachingError(f"Invalid teaching {key}: {type_id}")
    roles = card["threadRoles"]
    if not isinstance(roles, list):
        raise PipelineTeachingError(f"Invalid teaching threadRoles: {type_id}")
    for role in roles:
        if (
            not isinstance(role, dict)
            or not {"thread", "responsibility"}.issubset(role)
            or set(role) - {"thread", "responsibility", "traceTag"}
            or not _text(role["thread"])
            or not _text(role["responsibility"])
            or ("traceTag" in role and not _text(role["traceTag"]))
        ):
            raise PipelineTeachingError(f"Invalid teaching thread role: {type_id}")
    return deepcopy(value)


def _cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", "<br>")


def _code(value: str) -> str:
    fence = "`" * (max((len(match[0]) for match in re.finditer(r"`+", value)), default=0) + 1)
    return f"{fence} {value} {fence}"


@dataclass(frozen=True)
class PipelineTeachingCatalog:
    source_sha256: str
    _rendering_types: dict[str, dict[str, Any]]
    _pipelines: dict[str, str]

    def descriptor(self) -> dict[str, Any]:
        return {
            "source_path": SOURCE_PATH,
            "source_sha256": self.source_sha256,
            "destination": DESTINATION,
            "rendering_types": sorted(self._rendering_types),
            "pipelines": dict(sorted(self._pipelines.items())),
        }

    def project(self, value: object) -> object:
        """Copy structured values and project references in prose and SQL alike."""
        if isinstance(value, dict):
            return {key: self.project(item) for key, item in value.items()}
        if isinstance(value, list):
            return [self.project(item) for item in value]
        if not isinstance(value, str):
            return value

        def replace(match: re.Match[str]) -> str:
            preceding = value[match.start() - 1:match.start()] if match.start() else ""
            following = value[match.end():match.end() + 1]
            if preceding and (preceding.isalnum() or preceding in "_./\\-"):
                raise PipelineTeachingError("Unsafe product catalog reference path")
            if following and (following.isalnum() or following in "_/\\#"):
                raise PipelineTeachingError("Invalid product catalog reference suffix")
            if following == "." and value[match.end() + 1:match.end() + 2].isalnum():
                raise PipelineTeachingError("Invalid product catalog reference suffix")
            fragment = match["fragment"]
            if fragment is None:
                return DESTINATION
            type_id = _reference_id(f"{match['path']}#{fragment}")
            if type_id not in self._rendering_types:
                raise PipelineTeachingError("Unknown rendering type in teaching reference")
            return f"{DESTINATION}#{type_id.lower()}"

        return _REFERENCE.sub(replace, value)

    def render(self) -> str:
        lines = [
            "GENERATED FILE - DO NOT EDIT.",
            f"Source: {SOURCE_PATH}",
            f"Source SHA-256: {self.source_sha256}",
            "",
            "# Rendering teaching cards",
            "",
            "These concise product cards describe reference topology and evidence boundaries. "
            "They are guidance, not proof that a path occurred in a trace.",
            "",
            "## Pipeline lookup",
            "",
            "| Pipeline | Teaching card |",
            "| --- | --- |",
        ]
        for pipeline_id, type_id in sorted(self._pipelines.items()):
            lines.append(f"| {_code(pipeline_id)} | [{type_id}](#{type_id.lower()}) |")
        for type_id, rendering_type in sorted(self._rendering_types.items()):
            card = rendering_type["teaching"]
            lines.extend([
                "", f'<a id="{type_id.lower()}"></a>',
                f"## {card['title']}", "",
                f"- Rendering type: {_code(type_id)}",
                f"- Kind: {_code(rendering_type['kind'])}",
                "", card["summary"],
            ])
            for diagram in card["mermaidBlocks"]:
                fence = "`" * max(3, max((len(match[0]) + 1 for match in re.finditer(r"`+", diagram)), default=0))
                lines.extend(["", f"{fence}mermaid", diagram, fence])
            if card["threadRoles"]:
                lines.extend([
                    "", "### Thread roles", "",
                    "| Thread | Responsibility | Trace tag |", "| --- | --- | --- |",
                ])
                for role in card["threadRoles"]:
                    lines.append(
                        f"| {_cell(role['thread'])} | {_cell(role['responsibility'])} "
                        f"| {_cell(role.get('traceTag', ''))} |"
                    )
            if card["keySlices"]:
                lines.extend(["", "### Key slices", ""])
                lines.extend(f"- {_code(name)}" for name in card["keySlices"])
        header = "\n".join(lines[:3]) + "\n\n"
        body = "\n".join(line.rstrip() for line in lines[4:]).rstrip() + "\n"
        return header + str(self.project(body))


def load_pipeline_teaching(
    source: Path, skill_entries: list[dict[str, Any]]
) -> PipelineTeachingCatalog | None:
    entries = [
        entry for entry in skill_entries
        if entry.get("runtime_type") == "pipeline_definition"
        and entry.get("disposition") in {"exported", "merged"}
    ]
    if not entries:
        return None
    source = source.expanduser().resolve()
    catalog, source_hash = _read_yaml(source, SOURCE_PATH)
    if catalog.get("version") != "3.0" or any(key in catalog for key in ("source", "documents", "document")):
        raise PipelineTeachingError("Pipeline teaching requires the product v3 catalog")
    types = catalog.get("rendering_types")
    if not isinstance(types, dict) or not types:
        raise PipelineTeachingError("Pipeline teaching requires rendering types")
    rendering_types = {type_id: _validate_card(type_id, value) for type_id, value in types.items()}
    declared = catalog.get("pipelines")
    if not isinstance(declared, dict) or not declared:
        raise PipelineTeachingError("Pipeline teaching requires pipeline mappings")
    filenames: set[str] = set()
    for pipeline_id, entry in declared.items():
        if not _identifier(pipeline_id) or not isinstance(entry, dict):
            raise PipelineTeachingError("Invalid pipeline teaching mapping")
        filename = entry.get("file")
        if (
            not _safe_relative(filename) or PurePosixPath(filename).name != filename
            or not filename.endswith(".skill.yaml") or filename in filenames
        ):
            raise PipelineTeachingError(f"Unsafe pipeline definition path: {pipeline_id}")
        filenames.add(filename)
        if not _identifier(entry.get("teaching_type_id")) or entry["teaching_type_id"] not in rendering_types:
            raise PipelineTeachingError(f"Unknown pipeline teaching type: {pipeline_id}")
        rendering_type_id = entry.get("rendering_type_id", entry["teaching_type_id"])
        if not _identifier(rendering_type_id) or rendering_type_id not in rendering_types:
            raise PipelineTeachingError(f"Unknown pipeline rendering type: {pipeline_id}")
        related = entry.get("related_rendering_type_ids", [])
        if not isinstance(related, list) or any(not _identifier(type_id) or type_id not in rendering_types for type_id in related):
            raise PipelineTeachingError(f"Unknown related rendering type: {pipeline_id}")
    default = catalog.get("default")
    if (
        not isinstance(default, dict) or not _identifier(default.get("pipeline_id"))
        or default["pipeline_id"] not in declared
        or default.get("rendering_type_id") != declared[default["pipeline_id"]]["teaching_type_id"]
    ):
        raise PipelineTeachingError("Invalid default rendering teaching type")
    pipelines: dict[str, str] = {}
    for entry in entries:
        relative = entry.get("source_path")
        if (
            not _safe_relative(relative)
            or PurePosixPath(relative).parent.as_posix() != "backend/skills/pipelines"
            or not relative.endswith(".skill.yaml")
        ):
            raise PipelineTeachingError("Exported pipeline must name a pipeline definition file")
        raw, _ = _read_yaml(source, relative)
        if raw.get("type") != "pipeline_definition" or not isinstance(raw.get("meta"), dict):
            raise PipelineTeachingError("Exported pipeline source has invalid type or metadata")
        pipeline_id = raw["meta"].get("pipeline_id")
        if not _identifier(pipeline_id) or pipeline_id not in declared or pipeline_id in pipelines:
            raise PipelineTeachingError("Unknown or duplicate exported pipeline ID")
        mapping = declared[pipeline_id]
        if relative != f"backend/skills/pipelines/{mapping['file']}":
            raise PipelineTeachingError(f"Pipeline source disagrees with catalog: {pipeline_id}")
        type_id = mapping["teaching_type_id"]
        teaching = raw.get("teaching")
        if (
            not isinstance(teaching, dict)
            or _reference_id(teaching.get("source")) != type_id
            or _reference_id(raw["meta"].get("doc_path")) != type_id
        ):
            raise PipelineTeachingError(f"Pipeline teaching references disagree with catalog: {pipeline_id}")
        pipelines[pipeline_id] = type_id
    return PipelineTeachingCatalog(source_hash, rendering_types, pipelines)
