#!/usr/bin/env python3
"""SmartPerfetto's process identity gate, ported for the portable runtime.

The gate decides, before a Skill runs, whether its process selectors name one
verified process, and rewrites name aliases to the resolver's recommended
`process.name` parameter. It mirrors SmartPerfetto's
backend/src/services/processIdentity/identityGate.ts and the resolver
normalization in skillExecutor.ts (resolveProcessIdentityForGate,
normalizeIdentityStatus, identityQualityWarnings, rowToIdentityCandidate), so
both products admit or refuse the same invocation on the same trace and use
the same reason text. The candidates come from the exported
process_identity_resolver Skill.

One deliberate boundary: this runtime has no exact-UPID SQL scope, so an
invocation the gate would scope to an explicit UPID or PID is refused with an
explicit reason instead of running unscoped.
"""
from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
import json
import math
import weakref
from typing import Any


DEFAULT_PROCESS_IDENTITY_ALIASES = (
    "package", "process_name", "package_name", "target_package", "app_package", "packageName", "processName",
)
PROCESS_IDENTITY_SELECTORS = (*DEFAULT_PROCESS_IDENTITY_ALIASES, "upid", "pid", "thread_name", "threadName")
RESOLVER_SKILL = "process_identity_resolver"
EXACT_SCOPE_UNSUPPORTED = (
    "Exact UPID scope is unsupported in the portable runtime; select the process by name"
)

# Resolver(params) -> (success, rows, error); PidCounter(pid) -> (process_count, unique_upid).
Resolver = Callable[[Mapping[str, Any]], "tuple[bool, list[Mapping[str, Any]], str | None]"]
PidCounter = Callable[[int], "tuple[Any, Any]"]


def _js_number(value: Any) -> float | None:
    """JavaScript Number(value) for the scalars a resolver row holds; None when not finite."""
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return float(value)
    if isinstance(value, (int, float)):
        number = float(value)
    else:
        text = str(value).strip()
        if text == "":
            return 0.0
        try:
            number = float(text)
        except ValueError:
            return None
    return number if math.isfinite(number) else None


def _to_number(value: Any) -> int | float | None:
    number = _js_number(value)
    if number is None:
        return None
    return int(number) if number.is_integer() and abs(number) <= 2 ** 53 - 1 else number


def _text(value: Any) -> str | None:
    """`row.x ? String(row.x) : undefined`: JavaScript truthiness decides presence."""
    if value is None or value is False or value == "" or (isinstance(value, (int, float)) and value == 0):
        return None
    if value is True:
        return "true"
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def _first_value(source: Mapping[str, Any], keys: tuple[str, ...] | list[str]) -> Any:
    for key in keys:
        value = source.get(key)
        if value is not None and str(value).strip() != "":
            return value
    return None


def _coerce_integer(value: Any) -> int | None:
    if value is None or str(value).strip() == "":
        return None
    number = _js_number(value)
    if number is None or not number.is_integer() or abs(number) > 2 ** 53 - 1 or number <= 0:
        return None
    return int(number)


def _split_sources(*values: Any) -> list[str]:
    sources: list[str] = []
    for value in values:
        if not isinstance(value, str):
            continue
        for part in value.split(","):
            source = part.strip()
            if source and source not in sources:
                sources.append(source)
    return sources


def identity_config(skill: Mapping[str, Any]) -> dict[str, Any]:
    """The effective identity contract the exporter recorded for this Skill."""
    if skill.get("id") == RESOLVER_SKILL:
        return {"policy": "exempt", "scope": "process"}
    config = skill.get("identity") or {"policy": "none"}
    return dict(config) if isinstance(config, Mapping) else {"policy": "none"}


def _declared_inputs(skill: Mapping[str, Any]) -> list[str]:
    return [str(spec["name"]) for spec in skill.get("inputs", []) or [] if isinstance(spec, Mapping) and "name" in spec]


def consumable_selectors(skill: Mapping[str, Any]) -> set[str]:
    """getConsumableProcessIdentitySelectors: selectors this Skill or its gate consumes."""
    declared = set(_declared_inputs(skill))
    allowed = {key for key in PROCESS_IDENTITY_SELECTORS if key in declared}
    config = identity_config(skill)
    process_scope = skill.get("process_scope") if isinstance(skill.get("process_scope"), Mapping) else None
    target_binding = bool(process_scope and process_scope.get("role") == "target" and process_scope.get("binding"))
    has_process_gate = (
        config.get("scope") == "process"
        and config.get("policy") in {"required", "verify_if_present"}
        and (process_scope is None or process_scope.get("role") == "target")
    )
    if has_process_gate:
        allowed.update(DEFAULT_PROCESS_IDENTITY_ALIASES, config.get("aliases") or [], ("upid", "pid"))
    elif target_binding:
        allowed.update(("upid", "pid"))
    for key in ("thread_name", "threadName"):
        if key not in declared:
            allowed.discard(key)
    return allowed


def extract_target(params: Mapping[str, Any], inherited: Mapping[str, Any], config: Mapping[str, Any]) -> dict[str, Any]:
    aliases = list(config.get("aliases") or DEFAULT_PROCESS_IDENTITY_ALIASES)
    explicit = _first_value(params, [*DEFAULT_PROCESS_IDENTITY_ALIASES, *aliases, "upid", "pid"]) is not None
    requested = _first_value(params, [*aliases, *DEFAULT_PROCESS_IDENTITY_ALIASES])
    if requested is None and not explicit:
        requested = _first_value(inherited, aliases)
    thread = _first_value(params, ["thread_name", "threadName"])
    if thread is None:
        thread = _first_value(inherited, ["thread_name", "threadName"])
    upid = _coerce_integer(_first_value(params, ["upid"]) if _first_value(params, ["upid"]) is not None or explicit
                           else _first_value(inherited, ["upid"]))
    pid = _coerce_integer(_first_value(params, ["pid"]) if _first_value(params, ["pid"]) is not None or explicit
                          else _first_value(inherited, ["pid"]))
    start = _first_value(params, ["start_ts", "startTs"])
    if start is None:
        start = _first_value(inherited, ["start_ts", "startTs"])
    end = _first_value(params, ["end_ts", "endTs"])
    if end is None:
        end = _first_value(inherited, ["end_ts", "endTs"])
    target: dict[str, Any] = {}
    if requested is not None:
        target["requestedName"] = str(requested).strip()
    if thread is not None:
        target["threadName"] = str(thread).strip()
    if upid is not None:
        target["upid"] = upid
    if pid is not None:
        target["pid"] = pid
    if start is not None:
        target["startTs"] = start
    if end is not None:
        target["endTs"] = end
    return target


def _has_target(target: Mapping[str, Any]) -> bool:
    return bool(target.get("requestedName") or target.get("threadName") or "upid" in target or "pid" in target)


def _candidate(row: Mapping[str, Any]) -> dict[str, Any]:
    thread_utid = _to_number(row.get("thread_utid"))
    role = row.get("thread_role")
    return {
        "rank": _to_number(row.get("rank")) or 0,
        "confidenceScore": _to_number(row.get("confidence_score")) or 0,
        "rawStatus": _text(row.get("identity_status")),
        "canonicalPackageName": _text(row.get("canonical_package_name")),
        "recommendedProcessNameParam": _text(row.get("recommended_process_name_param")),
        "upid": _to_number(row.get("upid")),
        "pid": _to_number(row.get("pid")),
        "processName": _text(row.get("process_name")),
        "metadataProcessName": _text(row.get("metadata_process_name")),
        "packageName": _text(row.get("package_name")),
        "cmdline": _text(row.get("cmdline")),
        "targetMatchSources": _text(row.get("target_match_sources")),
        "supportingSources": _text(row.get("supporting_sources")),
        "identityWarning": _text(row.get("identity_warning")),
        "threadUtid": thread_utid,
        "threadTid": _to_number(row.get("thread_tid")),
        "threadName": _text(row.get("thread_name")),
        "threadRole": role if role in {"app_main", "render_thread"} else ("unknown" if thread_utid is not None else None),
        "threadTargetMatched": _to_number(row.get("thread_target_matched")) == 1,
    }


def _exact_process_id(target: Mapping[str, Any], candidate: Mapping[str, Any] | None) -> bool:
    if not candidate:
        return False
    return bool(
        "upid" in target and candidate.get("upid") == target["upid"]
        and "upid" in _split_sources(candidate.get("targetMatchSources"))
    )


def _exact_process_name(target: Mapping[str, Any], candidate: Mapping[str, Any] | None) -> bool:
    requested = (target.get("requestedName") or "").strip()
    if not requested or not candidate:
        return False
    return any(
        candidate.get(key) == requested
        for key in ("processName", "metadataProcessName", "cmdline", "recommendedProcessNameParam")
    )


def quality_warnings(candidate: Mapping[str, Any] | None, candidates: list[Mapping[str, Any]], target: Mapping[str, Any]) -> list[str]:
    if not candidate:
        return []
    warnings: list[str] = []

    def add(message: str) -> None:
        if message not in warnings:
            warnings.append(message)

    if candidate.get("identityWarning") and candidate["identityWarning"] != "ok":
        add(candidate["identityWarning"])
    sources = _split_sources(candidate.get("targetMatchSources"))
    has_process_target = bool(target.get("requestedName") or "upid" in target or "pid" in target)
    exact_id = _exact_process_id(target, candidate)
    process_level = [source for source in sources if source != "thread.name"]
    if target.get("threadName") and not has_process_target:
        add("thread-only identity target is not enough to verify a unique process")
    if not process_level:
        add("identity candidate has no process-level target match source")
    if candidate.get("rawStatus") == "probable" and not exact_id:
        add("probable identity match requires additional confirmation before parameter rewrite")
    close = [
        item for item in candidates
        if item is not candidate and item["confidenceScore"] > 0
        and candidate["confidenceScore"] - item["confidenceScore"] < 20
    ]
    exact_requested = _exact_process_name(target, candidate)
    close_exact = any(_exact_process_name(target, item) for item in close)
    if close and (not exact_requested or close_exact):
        add("multiple close process identity candidates require manual confirmation")
    return warnings


def _normalize_status(candidate: Mapping[str, Any] | None, candidates: list[Mapping[str, Any]], target: Mapping[str, Any]) -> str:
    if not candidate or candidate["confidenceScore"] <= 0:
        return "not_found"
    exact_id = _exact_process_id(target, candidate)
    if not quality_warnings(candidate, candidates, target) and (
        (candidate.get("rawStatus") == "confirmed" and candidate["confidenceScore"] >= 80)
        or (exact_id and candidate["confidenceScore"] >= 50)
    ):
        return "verified"
    return "ambiguous"


def _unresolved(target: Mapping[str, Any], error: str) -> dict[str, Any]:
    return {
        "status": "unresolved", "requestedName": target.get("requestedName"), "upids": [],
        "confidenceScore": 0, "evidenceSources": [], "warnings": [], "candidates": [], "resolverError": error,
    }


def resolve(target: Mapping[str, Any], resolver: Resolver, count_pid: PidCounter) -> dict[str, Any]:
    """resolveProcessIdentityForGate without its cache."""
    params: dict[str, Any] = {"max_rows": 10}
    if target.get("requestedName"):
        params["package"] = target["requestedName"]
        params["process_name"] = target["requestedName"]
    for key, name in (("threadName", "thread_name"), ("upid", "upid"), ("pid", "pid"), ("startTs", "start_ts"), ("endTs", "end_ts")):
        if key in target:
            params[name] = target[key]
    try:
        verified_target = dict(target)
        if "pid" in target and "upid" not in target:
            count, upid = count_pid(int(target["pid"]))
            count, upid = _to_number(count), _to_number(upid)
            if count is None or not isinstance(count, int) or count < 0:
                raise ValueError("PID uniqueness count is unavailable")
            if count != 1:
                return {
                    "status": "not_found" if count == 0 else "ambiguous", "requestedName": target.get("requestedName"),
                    "upids": [], "confidenceScore": 0, "candidates": [], "evidenceSources": ["process.pid"],
                    "warnings": [f"PID {target['pid']} maps to {count} UPIDs in this trace; select an explicit UPID."],
                }
            if upid is None or not isinstance(upid, int) or upid <= 0:
                raise ValueError("PID uniqueness query returned an invalid UPID")
            verified_target["upid"] = upid
            params["upid"] = upid
        success, rows, error = resolver(params)
        if not success:
            return _unresolved(target, error or f"{RESOLVER_SKILL} failed")
        candidates = [
            candidate for candidate in (_candidate(row) for row in rows)
            if "upid" not in verified_target or candidate["upid"] == verified_target["upid"]
        ]
        top = candidates[0] if candidates else None
        status = _normalize_status(top, candidates, verified_target)
        return {
            "status": status,
            "requestedName": target.get("requestedName"),
            "canonicalPackageName": top.get("canonicalPackageName") if top else None,
            "recommendedProcessNameParam": top.get("recommendedProcessNameParam") if top else None,
            "upids": [top["upid"]] if top and top.get("upid") is not None and status == "verified" else [],
            "confidenceScore": top["confidenceScore"] if top else 0,
            "rawStatus": top.get("rawStatus") if top else None,
            "evidenceSources": _split_sources(
                top.get("targetMatchSources") if top else None,
                top.get("supportingSources") if top else None,
                "process.pid_unique_upid" if verified_target != dict(target) else None,
            ),
            "warnings": quality_warnings(top, candidates, verified_target),
            "candidates": candidates,
        }
    except Exception as exc:  # noqa: BLE001 - SmartPerfetto records any resolver failure as unresolved.
        return _unresolved(target, str(exc) or f"{RESOLVER_SKILL} threw")


@dataclass(frozen=True, eq=False)
class IdentityScope:
    """A runtime-issued process scope; ordinary values cannot reissue one.

    It belongs to the gate that issued it, and a gate serves one trace and
    trace side, so a scope never carries an identity onto another trace.
    """

    mode: str  # "named" or "unscoped"
    requested_name: str | None = None
    _identity: tuple[dict[str, Any], dict[str, Any]] | None = field(default=None, repr=False)
    _owner: object = field(default=None, repr=False)

    def verified_identity(self) -> tuple[dict[str, Any], dict[str, Any]] | None:
        if self not in _issued_scopes or self._identity is None:
            return None
        target, resolution = self._identity
        return json.loads(json.dumps(target)), json.loads(json.dumps(resolution))


_issued_scopes: weakref.WeakSet[IdentityScope] = weakref.WeakSet()


def _issue_scope(
    owner: object, target: Mapping[str, Any] | None = None, resolution: Mapping[str, Any] | None = None,
) -> IdentityScope:
    requested = (target or {}).get("requestedName")
    identity = (
        (json.loads(json.dumps(dict(target))), json.loads(json.dumps(dict(resolution))))
        if target and resolution else None
    )
    scope = IdentityScope("named" if requested else "unscoped", requested, identity, owner)
    _issued_scopes.add(scope)
    return scope


@dataclass
class GateResult:
    allowed: bool
    params: dict[str, Any]
    config: dict[str, Any]
    target: dict[str, Any] | None = None
    resolution: dict[str, Any] | None = None
    scope: IdentityScope | None = None
    error: str | None = None
    warning: str | None = None

    def evidence(self) -> dict[str, Any]:
        """The identity record kept with the run and its evidence."""
        policy = self.config.get("policy", "none")
        resolution = self.resolution
        if resolution is None:
            status = "exempt" if policy in {"none", "exempt"} else "not_requested"
            record: dict[str, Any] = {"status": status, "policy": policy}
            if status == "not_requested":
                record["aliases"] = list(self.config.get("aliases") or [])
        else:
            status = "resolved" if self.allowed and resolution["status"] == "verified" else resolution["status"]
            record = {
                "status": status,
                "policy": policy,
                "gate_status": resolution["status"],
                "target": resolution.get("recommendedProcessNameParam") if status == "resolved" else resolution.get("requestedName"),
                "requested_name": resolution.get("requestedName"),
                "canonical_package_name": resolution.get("canonicalPackageName"),
                "confidence": resolution.get("confidenceScore"),
                "upid": resolution["upids"][0] if len(resolution.get("upids") or []) == 1 else None,
                "warnings": list(resolution.get("warnings") or []),
                "evidence_sources": list(resolution.get("evidenceSources") or []),
                "candidates": [
                    {key: candidate.get(key) for key in (
                        "upid", "pid", "processName", "packageName", "confidenceScore", "rawStatus", "recommendedProcessNameParam",
                    )}
                    for candidate in resolution.get("candidates") or []
                ],
            }
            if resolution.get("resolverError"):
                record["resolver_error"] = resolution["resolverError"]
        if self.warning:
            record["gate_warning"] = self.warning
        if self.error:
            record["error"] = self.error
        return record


def _rewrite_params(
    params: Mapping[str, Any], skill: Mapping[str, Any], target: Mapping[str, Any],
    resolution: Mapping[str, Any], config: Mapping[str, Any],
) -> dict[str, Any]:
    rewritten = dict(params)
    declared = set(_declared_inputs(skill))
    has_declarations = bool(skill.get("inputs"))
    if config.get("rewriteTo") == "upid" and len(resolution.get("upids") or []) == 1 and "upid" not in target:
        rewritten["upid"] = resolution["upids"][0]
        return rewritten
    recommended = resolution.get("recommendedProcessNameParam")
    if not recommended and "upid" not in target:
        return rewritten
    aliases = list(config.get("aliases") or DEFAULT_PROCESS_IDENTITY_ALIASES)
    for alias in aliases:
        if rewritten.get(alias) is not None and str(rewritten[alias]).strip() != "":
            rewritten[alias] = recommended
    if target.get("requestedName") or "upid" in target:
        if has_declarations:
            for alias in aliases:
                if alias in declared and alias not in rewritten:
                    rewritten[alias] = recommended or ""
        if "package" in rewritten or "package" in declared or not has_declarations:
            rewritten["package"] = recommended or ""
        if "process_name" in rewritten or "process_name" in declared or not has_declarations:
            rewritten["process_name"] = recommended or ""
        if has_declarations:
            for alias in aliases:
                if alias not in declared:
                    rewritten.pop(alias, None)
    if "upid" not in declared:
        rewritten.pop("upid", None)
    if "pid" not in declared:
        rewritten.pop("pid", None)
    return rewritten


def _verified(resolution: Mapping[str, Any], config: Mapping[str, Any]) -> bool:
    return resolution["status"] == "verified" and resolution["confidenceScore"] >= config.get("minConfidence", 50)


class IdentityGate:
    """IdentityGate.apply for one runner; caches resolutions like SmartPerfetto's executor."""

    def __init__(self, resolver: Resolver, count_pid: PidCounter) -> None:
        self._resolver = resolver
        self._count_pid = count_pid
        self._cache: dict[str, dict[str, Any]] = {}

    def resolve(self, target: Mapping[str, Any]) -> dict[str, Any]:
        key = json.dumps({
            "requestedName": target.get("requestedName") or "", "threadName": target.get("threadName") or "",
            "upid": target.get("upid"), "pid": target.get("pid"),
            "startTs": target.get("startTs"), "endTs": target.get("endTs"),
        }, sort_keys=True, default=str)
        cached = self._cache.get(key)
        if cached is not None:
            return json.loads(json.dumps(cached))
        resolution = resolve(target, self._resolver, self._count_pid)
        if not resolution.get("resolverError"):
            self._cache[key] = json.loads(json.dumps(resolution))
        return resolution

    def apply(
        self,
        skill: Mapping[str, Any],
        params: Mapping[str, Any],
        inherited: Mapping[str, Any],
        parent: IdentityScope | None = None,
    ) -> GateResult:
        skill_id = str(skill.get("id"))
        config = identity_config(skill)
        params = dict(params)

        def blocked(error: str, **extra: Any) -> GateResult:
            return GateResult(False, params, config, error=error, **extra)

        consumable = consumable_selectors(skill)
        unused_threads = [
            key for key in ("thread_name", "threadName")
            if _first_value(params, [key]) is not None and key not in consumable
        ]
        if unused_threads and skill_id != RESOLVER_SKILL:
            return blocked(f"Skill does not declare a thread filter input: {', '.join(unused_threads)}")
        if parent is not None and (parent not in _issued_scopes or parent._owner is not self):
            return blocked("Process scope is untrusted or belongs to a different trace/side")
        for key in ("upid", "pid"):
            value = _first_value(params, [key])
            if value is not None and _coerce_integer(value) is None:
                return blocked(f"Invalid explicit {key}: expected a positive safe integer")
        if skill_id == RESOLVER_SKILL:
            return GateResult(True, params, config, scope=parent or _issue_scope(self))
        target = extract_target(params, inherited, config)
        policy = config.get("policy", "none")
        if "upid" not in target and "pid" not in target and policy in {"none", "exempt"}:
            return GateResult(True, params, config, scope=parent or _issue_scope(self, target))
        if not _has_target(target):
            if policy == "required":
                return blocked(
                    f'Process identity is required before running skill "{skill_id}", '
                    "but no package/process/upid target was provided.",
                    target=target,
                )
            return GateResult(True, params, config, target=target, scope=parent or _issue_scope(self))

        prepared = parent.verified_identity() if parent is not None else None
        if prepared is not None and (prepared[1].get("status") != "verified" or prepared[1].get("resolverError")):
            prepared = None
        new_thread = bool(target.get("threadName")) and target.get("threadName") != (prepared[0].get("threadName") if prepared else None)
        same_named = bool(
            parent is not None and parent.mode == "named" and prepared and "upid" not in target and "pid" not in target
            and (not target.get("requestedName") or target["requestedName"] in (
                prepared[0].get("requestedName"), prepared[1].get("canonicalPackageName"),
                prepared[1].get("recommendedProcessNameParam"),
            ))
        )
        resolution = prepared[1] if same_named and prepared and not new_thread else self.resolve(target)

        aliases = list(dict.fromkeys([*DEFAULT_PROCESS_IDENTITY_ALIASES, *(config.get("aliases") or [])]))
        explicit = [(key, _first_value(params, [key])) for key in aliases if _first_value(params, [key]) is not None]
        explicit_names = [str(value).strip() for _key, value in explicit]

        def conflict(error: str) -> GateResult:
            resolution_copy = dict(resolution, status="ambiguous", upids=[], warnings=[*resolution.get("warnings", []), error])
            return GateResult(False, params, config, target=target, resolution=resolution_copy, error=error)

        if "pid" in target and "upid" not in target:
            selected = [
                candidate for candidate in resolution.get("candidates", [])
                if candidate.get("pid") == target["pid"] and candidate.get("upid") is not None
                and candidate["upid"] in resolution.get("upids", [])
            ]
            if (
                resolution["status"] != "verified" or len(resolution.get("upids", [])) != 1
                or not any(candidate["upid"] == resolution["upids"][0] for candidate in selected)
            ):
                return conflict(
                    "Explicit PID must resolve to one verified UPID; select the intended UPID when the PID was reused"
                )
            target = {**target, "upid": resolution["upids"][0]}
        if "upid" in target:
            selected = [candidate for candidate in resolution.get("candidates", []) if candidate.get("upid") == target["upid"]]
            if resolution["status"] != "verified" or resolution.get("upids") != [target["upid"]]:
                return conflict("Explicit UPID could not be verified; no other process may replace it")
            names = {
                value for value in (
                    *[candidate.get(key) for candidate in selected for key in (
                        "processName", "metadataProcessName", "packageName", "canonicalPackageName", "cmdline",
                        "recommendedProcessNameParam",
                    )],
                    resolution.get("canonicalPackageName"), resolution.get("recommendedProcessNameParam"),
                ) if value
            }
            process_names = {
                candidate.get(key) for candidate in selected
                for key in ("processName", "metadataProcessName", "cmdline", "recommendedProcessNameParam")
            }
            if not selected:
                process_names.add(resolution.get("recommendedProcessNameParam"))
            if any(
                str(value).strip() not in (process_names if key in {"process_name", "processName"} else names)
                for key, value in explicit
            ) or ("pid" in target and not any(candidate.get("pid") == target["pid"] for candidate in selected)):
                return conflict("Explicit process name/PID conflicts with the selected UPID")
            resolution = dict(resolution, upids=[target["upid"]], candidates=selected)
            if parent is not None and parent.mode == "named" and parent.requested_name:
                boundary = parent.requested_name
                if not any(
                    name == boundary or (name or "").startswith(f"{boundary}:")
                    for candidate in selected
                    for name in (
                        candidate.get("processName"), candidate.get("metadataProcessName"), candidate.get("packageName"),
                        candidate.get("canonicalPackageName"), candidate.get("cmdline"),
                    )
                ):
                    return conflict("Resolved UPID is outside the inherited named process scope")
        elif len(set(explicit_names)) > 1:
            known = {
                resolution.get("canonicalPackageName"), resolution.get("recommendedProcessNameParam"),
                *[
                    candidate.get(key)
                    for candidate in resolution.get("candidates", [])
                    if candidate.get("upid") is not None and candidate["upid"] in resolution.get("upids", [])
                    for key in ("processName", "packageName", "metadataProcessName", "canonicalPackageName", "cmdline")
                ],
            }
            if any(name not in known for name in explicit_names):
                return conflict("Explicit process selector aliases conflict")

        if not _verified(resolution, config):
            base = f'Process identity could not be verified for skill "{skill_id}"'
            reason = (
                f"{base}: resolver failed ({resolution['resolverError']})"
                if resolution.get("resolverError")
                else f"{base}: status={resolution['status']}, confidence={_js_text(resolution['confidenceScore'])}"
            )
            if policy == "verify_if_present" and resolution["status"] == "unresolved" and resolution.get("resolverError"):
                # SmartPerfetto keeps broad flows running when the resolver itself
                # is unavailable; the run records why it is unverified.
                return GateResult(
                    True, params, config, target=target, resolution=resolution,
                    scope=_issue_scope(self, target, resolution), warning=reason,
                )
            return GateResult(False, params, config, target=target, resolution=resolution, error=reason)

        if "upid" in target:
            # SmartPerfetto would scope this run to the verified UPID; this
            # runtime has no exact-UPID SQL scope, so it refuses instead.
            return GateResult(False, params, config, target=target, resolution=resolution, error=EXACT_SCOPE_UNSUPPORTED)
        rewritten = _rewrite_params(params, skill, target, resolution, config)
        return GateResult(
            True, rewritten, config, target=target, resolution=resolution,
            scope=parent if same_named else _issue_scope(self, target, resolution),
        )


def _js_text(value: Any) -> str:
    """How JavaScript prints a number in a template string."""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)
