from __future__ import annotations

from collections.abc import Callable, Mapping
import hashlib
import json
from typing import Any

from .expressions import evaluate, interpolate


QueryExecutor = Callable[..., list[dict[str, Any]]]


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")


def _meaningful(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, (str, list, tuple, dict)):
        return bool(value)
    return True


class SkillRunner:
    def __init__(
        self,
        manifest: Mapping[str, Any],
        query_executor: QueryExecutor,
        *,
        max_depth: int = 12,
        identity_resolver: Callable[[Mapping[str, Any], Mapping[str, Any]], Mapping[str, Any]] | None = None,
        prerequisite_checker: Callable[[Mapping[str, Any]], Mapping[str, Any]] | None = None,
    ):
        raw_skills = manifest.get("skills", {})
        self.skills = (
            {str(item["id"]): item for item in raw_skills}
            if isinstance(raw_skills, list)
            else dict(raw_skills)
        )
        self.query_executor = query_executor
        self.max_depth = max_depth
        self.identity_resolver = identity_resolver
        self.prerequisite_checker = prerequisite_checker

    def _inputs(self, skill: Mapping[str, Any], supplied: Mapping[str, Any]) -> dict[str, Any]:
        result = dict(supplied)
        expected_types = {
            "string": str,
            "number": (int, float),
            "integer": int,
            "boolean": bool,
            "timestamp": (int, float),
            "duration": (int, float),
            "array": list,
            "json_array": list,
            "object": dict,
        }
        for spec in skill.get("inputs", []) or []:
            name = str(spec["name"])
            if name not in result and "default" in spec:
                result[name] = spec["default"]
            if spec.get("required") and name not in result:
                raise ValueError(f"missing required input: {name}")
            if name not in result and not spec.get("required"):
                result[name] = None
            if name in result and spec.get("type") in expected_types:
                if result[name] is None and not spec.get("required"):
                    continue
                expected = expected_types[spec["type"]]
                if isinstance(result[name], bool) and spec["type"] in {"number", "integer", "timestamp", "duration"}:
                    raise ValueError(f"invalid {spec['type']} input: {name}")
                if not isinstance(result[name], expected):
                    raise ValueError(f"invalid {spec['type']} input: {name}")
        return result

    def _evidence(self, skill_id: str, step_id: str, query_id: str | None, params: Mapping[str, Any], status: str, rows: Any, error: str | None = None) -> dict[str, Any]:
        payload = {
            "skill_id": skill_id,
            "step_id": step_id,
            "query_id": query_id,
            "params": params,
            "status": status,
            "rows": rows,
            "error": error,
        }
        return {
            "evidence_id": "ev_" + hashlib.sha256(_canonical(payload)).hexdigest()[:24],
            **payload,
            "row_count": len(rows) if isinstance(rows, list) else None,
        }

    def _extract_child_rows(self, result: Mapping[str, Any]) -> list[dict[str, Any]]:
        for step in result.get("steps", []):
            rows = step.get("rows")
            if step.get("status") == "observed" and _meaningful(rows):
                return rows
        return []

    def _resolve_param(self, value: Any, context: Mapping[str, Any]) -> Any:
        if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
            return evaluate(value, context)
        return value

    def run(self, skill_id: str, params: Mapping[str, Any] | None = None, *, _depth: int = 0, _inherited: Mapping[str, Any] | None = None) -> dict[str, Any]:
        if _depth > self.max_depth:
            raise RuntimeError(f"Skill recursion depth exceeds {self.max_depth}")
        if skill_id not in self.skills:
            raise KeyError(f"unknown Skill: {skill_id}")
        skill = self.skills[skill_id]
        runtime_status = skill.get("runtime_status", "executable")
        if runtime_status != "executable":
            return {"skill_id": skill_id, "success": False, "status": runtime_status, "steps": [], "evidence": []}
        inputs = self._inputs(skill, params or {})
        prerequisite = (
            dict(self.prerequisite_checker(skill))
            if self.prerequisite_checker is not None
            else {"status": "satisfied", "missing": []}
        )
        if prerequisite.get("status") != "satisfied":
            return {
                "schema_version": 1,
                "skill_id": skill_id,
                "success": False,
                "status": "missing_evidence",
                "params": inputs,
                "prerequisite": prerequisite,
                "steps": [],
                "evidence": [],
            }
        identity_policy = skill.get("identity", {}) or {"policy": "none"}
        identity = (
            dict(self.identity_resolver(skill, inputs))
            if self.identity_resolver is not None
            else {"status": "not_checked", "policy": identity_policy.get("policy", "none")}
        )
        if identity_policy.get("policy") == "required" and identity.get("status") != "resolved":
            return {
                "schema_version": 1,
                "skill_id": skill_id,
                "success": False,
                "status": "identity_blocked",
                "params": inputs,
                "identity": identity,
                "steps": [],
                "evidence": [],
            }
        variables: dict[str, Any] = dict(_inherited or {})
        context: dict[str, Any] = {**variables, **inputs, "inputs": inputs}
        steps = list(skill.get("steps", []) or [])
        if skill.get("type") == "atomic" and skill.get("query_id"):
            steps = [{"id": "root", "type": "atomic", "query_id": skill["query_id"]}]
        output_steps: list[dict[str, Any]] = []
        evidence: list[dict[str, Any]] = []
        required_error = False

        for step in steps:
            step_id = str(step["id"])
            step_type = str(step.get("type") or ("skill" if step.get("skill") else "atomic"))
            condition = step.get("condition")
            if isinstance(condition, str) and not bool(evaluate(condition, context)):
                output_steps.append({"step_id": step_id, "type": step_type, "status": "skipped_condition"})
                continue
            if step_type == "atomic":
                query_id = step.get("query_id")
                empty_dependencies = [
                    dependency
                    for dependency in step.get("result_dependencies", [])
                    if not isinstance(variables.get(str(dependency)), Mapping)
                    or not variables[str(dependency)].get("data")
                ]
                if empty_dependencies:
                    output_steps.append(
                        {
                            "step_id": step_id,
                            "type": step_type,
                            "status": "skipped_empty_dependency",
                            "dependencies": empty_dependencies,
                        }
                    )
                    continue
                try:
                    query_output = self.query_executor(
                        query_id,
                        params=inputs,
                        results=variables,
                        prelude=step.get("setup_queries", []),
                    )
                    metadata: dict[str, Any] = {}
                    if isinstance(query_output, Mapping) and isinstance(query_output.get("rows"), list):
                        rows = query_output["rows"]
                        metadata = dict(query_output.get("metadata", {}))
                    else:
                        rows = query_output
                    status = "observed" if rows else "empty"
                    result = {"step_id": step_id, "type": step_type, "status": status, "rows": rows}
                    if not rows and step.get("on_empty"):
                        result["message"] = step["on_empty"]
                    variables[step_id] = {"data": rows}
                    if step.get("save_as"):
                        variables[str(step["save_as"])] = {"data": rows}
                    context.update(variables)
                    item = self._evidence(skill_id, step_id, str(query_id), inputs, status, rows)
                    item.update(metadata)
                    item.setdefault("identity", identity)
                except Exception as exc:
                    optional = bool(step.get("optional"))
                    result = {"step_id": step_id, "type": step_type, "status": "error", "error": str(exc), "optional": optional}
                    item = self._evidence(skill_id, step_id, str(query_id), inputs, "error", [], str(exc))
                    if not optional:
                        required_error = True
                output_steps.append(result)
                evidence.append(item)
                continue
            if step_type == "skill":
                child_params = {
                    key: self._resolve_param(value, context)
                    for key, value in (step.get("params", {}) or {}).items()
                }
                child = self.run(str(step["skill"]), child_params, _depth=_depth + 1, _inherited=variables)
                rows = self._extract_child_rows(child)
                status = "observed" if rows else ("empty" if child.get("success") else "error")
                optional = bool(step.get("optional"))
                result = {
                    "step_id": step_id,
                    "type": "skill",
                    "status": status,
                    "optional": optional,
                    "rows": rows,
                    "child": child,
                }
                if not rows and step.get("on_empty"):
                    result["message"] = step["on_empty"]
                if status == "error" and not optional:
                    required_error = True
                variables[step_id] = {"data": rows}
                if step.get("save_as"):
                    variables[str(step["save_as"])] = {"data": rows}
                context.update(variables)
                output_steps.append(result)
                evidence.extend(child.get("evidence", []))
                continue
            if step_type == "iterator":
                source = variables.get(str(step.get("source")), {})
                items = source.get("data", []) if isinstance(source, Mapping) else []
                filter_expression = step.get("filter")
                if isinstance(filter_expression, str):
                    items = [
                        item
                        for item in items
                        if isinstance(item, Mapping)
                        and bool(evaluate(filter_expression, {**context, **item, "item": item}))
                    ]
                maximum = int(step.get("max_items") or 100)
                item_results = []
                for index, item in enumerate(items[:maximum]):
                    mappings = step.get("item_params", {}) or {}
                    child_params = {
                        key: item.get(path, path) if isinstance(item, Mapping) else path
                        for key, path in mappings.items()
                    }
                    if not mappings and isinstance(item, Mapping):
                        child_params = dict(item)
                    child = self.run(str(step["item_skill"]), child_params, _depth=_depth + 1, _inherited={**variables, "item": item})
                    item_results.append({"index": index, "item": item, "result": child})
                    evidence.extend(child.get("evidence", []))
                failed_items = sum(
                    1 for item_result in item_results
                    if not item_result["result"].get("success")
                )
                optional = bool(step.get("optional"))
                status = (
                    "error" if failed_items
                    else "observed" if item_results
                    else "empty"
                )
                if failed_items and not optional:
                    required_error = True
                output_steps.append({
                    "step_id": step_id,
                    "type": "iterator",
                    "status": status,
                    "optional": optional,
                    "failed_items": failed_items,
                    "items": item_results,
                })
                continue
            if step_type == "diagnostic":
                diagnostics = []
                for rule in step.get("rules", []) or []:
                    if bool(evaluate(str(rule["condition"]), context)):
                        confidence = rule.get("confidence", "medium")
                        confidence = {"high": 0.9, "medium": 0.7, "low": 0.5}.get(confidence, confidence)
                        diagnostics.append(
                            {
                                "diagnosis": interpolate(str(rule["diagnosis"]), context),
                                "confidence": confidence,
                                "severity": rule.get("severity"),
                                "suggestions": [interpolate(str(value), context) for value in rule.get("suggestions", [])],
                            }
                        )
                status = "observed" if diagnostics else ("agent_action_required" if step.get("ai_assist") else "empty")
                output_steps.append({"step_id": step_id, "type": "diagnostic", "status": status, "diagnostics": diagnostics})
                continue
            if step_type in {"ai_summary", "ai_decision"}:
                output_steps.append({"step_id": step_id, "type": step_type, "status": "agent_action_required"})
                continue
            output_steps.append({"step_id": step_id, "type": step_type, "status": "unsupported"})
            required_error = True

        return {
            "schema_version": 1,
            "skill_id": skill_id,
            "success": not required_error,
            "status": "completed" if not required_error else "error",
            "params": inputs,
            "prerequisite": prerequisite,
            "identity": identity,
            "steps": output_steps,
            "evidence": evidence,
        }
