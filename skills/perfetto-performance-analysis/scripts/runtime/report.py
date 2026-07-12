from __future__ import annotations

import json
from pathlib import Path
import re
from typing import Any, Mapping


CLAIM_CLASSES = {"observation", "correlation", "mechanism", "causal", "root_cause"}
REPORT_SCHEMA = Path(__file__).resolve().parents[2] / "assets" / "report-schema.json"


def _schema_issues(value: Any, schema: Mapping[str, Any], path: str = "report") -> list[str]:
    issues: list[str] = []
    expected_type = schema.get("type")
    type_matches = {
        "object": isinstance(value, Mapping),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "integer": isinstance(value, int) and not isinstance(value, bool),
    }
    if expected_type in type_matches and not type_matches[expected_type]:
        return [f"{path} must be {expected_type}"]
    if "const" in schema and value != schema["const"]:
        issues.append(f"{path} must equal {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        issues.append(f"{path} must be one of {schema['enum']}")
    if isinstance(value, Mapping):
        for required in schema.get("required", []):
            if required not in value:
                issues.append(f"{path} is missing required property {required}")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    issues.append(f"{path} has unsupported property {key}")
        for key, child_schema in properties.items():
            if key in value and isinstance(child_schema, Mapping):
                issues.extend(_schema_issues(value[key], child_schema, f"{path}.{key}"))
    if isinstance(value, list):
        minimum = schema.get("minItems")
        if isinstance(minimum, int) and len(value) < minimum:
            issues.append(f"{path} requires at least {minimum} item(s)")
        item_schema = schema.get("items")
        if isinstance(item_schema, Mapping):
            for index, item in enumerate(value):
                issues.extend(_schema_issues(item, item_schema, f"{path}[{index}]"))
    if isinstance(value, str):
        minimum = schema.get("minLength")
        if isinstance(minimum, int) and len(value) < minimum:
            issues.append(f"{path} requires at least {minimum} character(s)")
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and re.fullmatch(pattern, value) is None:
            issues.append(f"{path} does not match {pattern}")
    if isinstance(value, int) and not isinstance(value, bool):
        minimum = schema.get("minimum")
        if isinstance(minimum, int) and value < minimum:
            issues.append(f"{path} must be at least {minimum}")
    return issues


def validate_report_payload(report: Any) -> list[str]:
    schema = json.loads(REPORT_SCHEMA.read_text(encoding="utf-8"))
    issues = _schema_issues(report, schema)
    if not isinstance(report, Mapping):
        return issues
    trace_items = report.get("trace")
    declared_traces = {
        (item.get("sha256"), item.get("side"))
        for item in trace_items
        if isinstance(trace_items, list) and isinstance(item, Mapping)
    } if isinstance(trace_items, list) else set()
    evidence_items = report.get("evidence")
    if not isinstance(evidence_items, list):
        return issues
    evidence_ids = [
        item.get("evidence_id")
        for item in evidence_items
        if isinstance(item, Mapping) and isinstance(item.get("evidence_id"), str)
    ]
    for evidence_id in sorted({value for value in evidence_ids if evidence_ids.count(value) > 1}):
        issues.append(f"duplicate evidence_id: {evidence_id}")
    evidence = {
        item.get("evidence_id"): item
        for item in evidence_items
        if isinstance(item, Mapping) and isinstance(item.get("evidence_id"), str)
    }
    for evidence_id, item in evidence.items():
        trace = item.get("trace")
        trace_key = (
            trace.get("sha256"), trace.get("side")
        ) if isinstance(trace, Mapping) else (None, None)
        if trace_key not in declared_traces:
            issues.append(f"evidence {evidence_id} trace is not declared by report trace")
        processor = item.get("processor")
        if not isinstance(processor, Mapping) or processor.get("status") not in {
            "verified",
            "unsupported",
        }:
            issues.append(f"evidence {evidence_id} has no processor identity")
    findings = report.get("findings")
    if not isinstance(findings, list):
        return issues
    for finding_index, finding in enumerate(findings):
        if not isinstance(finding, Mapping):
            issues.append(f"finding {finding_index} must be an object")
            continue
        claim_class = finding.get("claim_class")
        if claim_class not in CLAIM_CLASSES:
            issues.append(f"finding {finding_index} has invalid claim_class")
        references = finding.get("evidence")
        if not isinstance(references, list) or not references:
            issues.append(f"finding {finding_index} has no evidence anchors")
            continue
        for anchor_index, anchor in enumerate(references):
            label = f"finding {finding_index} evidence {anchor_index}"
            if not isinstance(anchor, Mapping):
                issues.append(f"{label} must be an object")
                continue
            item = evidence.get(anchor.get("evidence_id"))
            if item is None:
                issues.append(f"{label} references unknown evidence")
                continue
            rows = item.get("rows")
            row_index = anchor.get("row")
            column = anchor.get("column")
            if not isinstance(rows, list) or not isinstance(row_index, int) or not 0 <= row_index < len(rows):
                issues.append(f"{label} has an invalid row selector")
                continue
            row = rows[row_index]
            if not isinstance(row, Mapping) or column not in row:
                issues.append(f"{label} has an invalid column selector")
                continue
            if "expected" in anchor and row[column] != anchor["expected"]:
                issues.append(f"{label} expected value does not match the evidence cell")
            if claim_class in {"causal", "root_cause"}:
                if item.get("status") != "observed":
                    issues.append(f"{label} cannot support a causal claim without observed evidence")
                validation = item.get("validation", {})
                if not validation.get("semantic_verified"):
                    issues.append(f"{label} cannot support a causal claim without semantic verification")
                processor = item.get("processor", {})
                if processor.get("status") != "verified":
                    issues.append(f"{label} cannot support a causal claim without a verified processor")
                identity = item.get("identity", {})
                if identity.get("status") != "resolved":
                    issues.append(f"{label} cannot support a causal claim with unresolved identity")
        if claim_class in {"mechanism", "causal", "root_cause"} and not finding.get("mechanism"):
            issues.append(f"finding {finding_index} requires a mechanism")
        if claim_class in {"causal", "root_cause"} and not finding.get("falsifier"):
            issues.append(f"finding {finding_index} requires a falsifier")
    if not isinstance(report.get("limitations"), list):
        issues.append("report limitations must be an array")
    return issues
