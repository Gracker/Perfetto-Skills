from __future__ import annotations

from collections.abc import Callable, Mapping
import hashlib
import json
import math
from typing import Any
from _common import reject_process_scope_names

from .expressions import evaluate, interpolate, is_expression_param, validate, validate_template


QueryExecutor = Callable[..., list[dict[str, Any]]]


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")


class SkillInputError(ValueError):
    """A Skill call whose parameters do not satisfy the Skill's input contract."""


def _declared_inputs(skill: Mapping[str, Any]) -> list[str]:
    return [str(spec["name"]) for spec in skill.get("inputs", []) or []]


_EXPECTED_TYPES = {
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
_NUMERIC_TYPES = frozenset({"number", "integer", "timestamp", "duration"})


def _reject_undeclared(skill_id: str, skill: Mapping[str, Any], declared: list[str], names: list[str]) -> None:
    message = (
        f"{skill_id} rejects undeclared input(s): {', '.join(names)}; "
        f"declared inputs: {', '.join(sorted(declared)) or 'none'}"
    )
    aliases = [str(name) for name in (skill.get("identity", {}) or {}).get("aliases", []) or []]
    bound = [name for name in aliases if name in declared]
    for name in sorted(set(names) & set(aliases)):
        # Aliases only select the process for identity verification; SQL reads
        # the declared input, so an alias alone would run the query unscoped.
        message += (
            f"; identity alias {name} only verifies the target process and is not bound into SQL; "
            + (f"pass the value as {' or '.join(bound)}" if bound else "this Skill binds no process name input")
        )
    raise SkillInputError(message)


def resolve_inputs(skill_id: str, skill: Mapping[str, Any], supplied: Mapping[str, Any]) -> dict[str, Any]:
    """Apply the Skill's input contract; a supplied name it does not declare is never ignored."""
    return _resolve_inputs(skill_id, skill, supplied)[0]


def _resolve_inputs(
    skill_id: str, skill: Mapping[str, Any], supplied: Mapping[str, Any]
) -> tuple[dict[str, Any], set[str]]:
    """The resolved inputs and the optional ones the caller left unset.

    An unset optional input reads as null in SQL (its `|default`, else NULL)
    but binds no name, so it does not hide a value the caller passed down.
    """
    unset: set[str] = set()
    declared = _declared_inputs(skill)
    undeclared = sorted(set(supplied) - set(declared))
    if undeclared:
        _reject_undeclared(skill_id, skill, declared, undeclared)
    result = dict(supplied)
    for spec in skill.get("inputs", []) or []:
        name = str(spec["name"])
        if name not in result and "default" in spec:
            result[name] = spec["default"]
        if spec.get("required") and name not in result:
            raise SkillInputError(f"{skill_id} missing required input: {name}")
        if name not in result and not spec.get("required"):
            result[name] = None
            unset.add(name)
        if name in result and spec.get("type") in _EXPECTED_TYPES:
            value = result[name]
            if value is None and not spec.get("required"):
                continue
            if (isinstance(value, bool) and spec["type"] in _NUMERIC_TYPES) or not isinstance(
                value, _EXPECTED_TYPES[spec["type"]]
            ):
                raise SkillInputError(f"{skill_id} invalid {spec['type']} input: {name}")
    return result, unset


def _meaningful(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, (str, list, tuple, dict)):
        return bool(value)
    return True


_RULE_CONFIDENCE = {"high": 0.9, "medium": 0.7, "low": 0.5}


def rule_confidence(value: Any) -> float:
    """A diagnostic rule's confidence; it is published as authored, never interpolated."""
    if isinstance(value, str) and value in _RULE_CONFIDENCE:
        return _RULE_CONFIDENCE[value]
    if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value):
        return value
    raise ValueError(f"unsupported rule confidence {value!r}: expected high, medium, low or a number")


def step_expressions(step: Mapping[str, Any]) -> list[tuple[str, Any, Callable[[Any], Any]]]:
    """Every value `SkillRunner.run` evaluates or interpolates for this step, as
    (field, value, check): each check raises ValueError where the run would."""
    checks: list[tuple[str, Any, Callable[[Any], Any]]] = []
    if isinstance(step.get("condition"), str):
        checks.append(("condition", step["condition"], validate))
    if isinstance(step.get("filter"), str):
        checks.append(("filter", step["filter"], validate))
    for name, value in (step.get("params") or {}).items():
        if is_expression_param(value):
            checks.append((f"params.{name}", value, validate))
    for index, rule in enumerate(step.get("rules") or []):
        field = f"rules[{index}]"
        checks.append((f"{field}.condition", str(rule.get("condition", "")), validate))
        checks.append((f"{field}.diagnosis", str(rule.get("diagnosis", "")), validate_template))
        for position, suggestion in enumerate(rule.get("suggestions") or []):
            checks.append((f"{field}.suggestions[{position}]", str(suggestion), validate_template))
        checks.append((f"{field}.confidence", rule.get("confidence", "medium"), rule_confidence))
    return checks


class SkillRunner:
    def __init__(
        self,
        manifest: Mapping[str, Any],
        query_executor: QueryExecutor,
        *,
        max_depth: int = 12,
        identity_resolver: Callable[[Mapping[str, Any], Mapping[str, Any]], Mapping[str, Any]] | None = None,
        prerequisite_checker: Callable[[Mapping[str, Any]], Mapping[str, Any]] | None = None,
        process_scope_enabled: bool = False,
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
        self.process_scope_enabled = process_scope_enabled

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

    @staticmethod
    def _named_child_rows(result: Mapping[str, Any], step_id: str) -> list[dict[str, Any]] | None:
        """Rows of one named child step, or None when that step observed nothing.

        A nested Skill that failed after returning some rows is marked observed;
        its partial rows are not a result of the named step.
        """
        for step in result.get("steps", []):
            rows = step.get("rows")
            if (
                step.get("step_id") == step_id
                and step.get("status") in {"observed", "empty"}
                and (step.get("child") or {}).get("success") is not False
                and isinstance(rows, list)
            ):
                return rows
        return None

    def _resolve_param(self, value: Any, context: Mapping[str, Any]) -> Any:
        if is_expression_param(value):
            return evaluate(value, context)
        return value

    def _run_child(self, skill_id: str, params: Mapping[str, Any], *, depth: int, inherited: Mapping[str, Any]) -> dict[str, Any]:
        try:
            return self.run(skill_id, params, _depth=depth, _inherited=inherited)
        except SkillInputError as exc:
            # A manifest-authored call that breaks the child's input contract is
            # a visible step failure; optional/required handling decides the parent.
            return {
                "schema_version": 1,
                "skill_id": skill_id,
                "success": False,
                "status": "input_rejected",
                "error": str(exc),
                "params": dict(params),
                "steps": [],
                "evidence": [],
            }

    def run(self, skill_id: str, params: Mapping[str, Any] | None = None, *, _depth: int = 0, _inherited: Mapping[str, Any] | None = None) -> dict[str, Any]:
        if _depth > self.max_depth:
            raise RuntimeError(f"Skill recursion depth exceeds {self.max_depth}")
        if skill_id not in self.skills:
            raise KeyError(f"unknown Skill: {skill_id}")
        skill = self.skills[skill_id]
        runtime_status = skill.get("runtime_status", "executable")
        if runtime_status != "executable":
            return {"skill_id": skill_id, "success": False, "status": runtime_status, "steps": [], "evidence": []}
        reject_process_scope_names(params or {})
        reject_process_scope_names(_inherited or {})
        for step in skill.get("steps", []) or []:
            reject_process_scope_names({name: None for name in (step.get("id"), step.get("save_as")) if name is not None})
        inputs, unset_inputs = _resolve_inputs(skill_id, skill, params or {})
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
        # A name resolves to this Skill's own step results and save_as bindings,
        # then its bound inputs, then what the caller passed down. `variables`
        # is what children inherit, so it keeps every caller value; `results`
        # (SQL, dependencies, iterator sources) and `context` (expressions)
        # drop the caller values a bound input shadows. Steps bind only their
        # own names, never the inherited ones again.
        inherited = _inherited or {}
        bound_inputs = inputs.keys() - unset_inputs
        variables: dict[str, Any] = dict(inherited)
        results: dict[str, Any] = {name: value for name, value in inherited.items() if name not in bound_inputs}
        context: dict[str, Any] = {**inputs, **results, "inputs": inputs}

        def bind(name: str, value: Any) -> None:
            variables[name] = context[name] = results[name] = value

        def unbind(name: str) -> None:
            for scope in (variables, context, results):
                scope.pop(name, None)

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
                    if not isinstance(results.get(str(dependency)), Mapping)
                    or not results[str(dependency)].get("data")
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
                    scope_context = (
                        {"identity_result": identity, "supplied_parameters": dict(params or {})}
                        if self.process_scope_enabled or skill.get("process_scope") or step.get("process_scope")
                        else {}
                    )
                    query_output = self.query_executor(
                        query_id,
                        params=inputs,
                        results=results,
                        prelude=step.get("setup_queries", []),
                        **scope_context,
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
                    bind(step_id, {"data": rows})
                    if step.get("save_as"):
                        bind(str(step["save_as"]), {"data": rows})
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
                child = self._run_child(str(step["skill"]), child_params, depth=_depth + 1, inherited=variables)
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
                bind(step_id, {"data": rows})
                if step.get("save_as"):
                    # save_from binds exactly one child step; when that step
                    # observed nothing the variable is unbound, never another
                    # step's rows or an earlier value.
                    saved = rows if "save_from" not in step else self._named_child_rows(child, str(step["save_from"]))
                    if saved is None:
                        unbind(str(step["save_as"]))
                    else:
                        bind(str(step["save_as"]), {"data": saved})
                output_steps.append(result)
                evidence.extend(child.get("evidence", []))
                continue
            if step_type == "iterator":
                source = results.get(str(step.get("source")), {})
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
                mappings = step.get("item_params", {}) or {}
                # Without explicit mappings, a row binds only its fields that the
                # child declares; extra result columns are data, not requested inputs.
                row_inputs = set(_declared_inputs(self.skills.get(str(step["item_skill"]), {})))
                for index, item in enumerate(items[:maximum]):
                    child_params = {
                        key: item.get(path, path) if isinstance(item, Mapping) else path
                        for key, path in mappings.items()
                    }
                    if not mappings and isinstance(item, Mapping):
                        child_params = {key: value for key, value in item.items() if key in row_inputs}
                    child = self._run_child(
                        str(step["item_skill"]), child_params,
                        depth=_depth + 1, inherited={**variables, "item": item},
                    )
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
                        confidence = rule_confidence(rule.get("confidence", "medium"))
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
