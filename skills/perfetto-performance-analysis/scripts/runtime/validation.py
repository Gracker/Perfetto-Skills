from __future__ import annotations

from typing import Any, Mapping


def validate_query_execution(
    entry: Mapping[str, Any],
    probe: Mapping[str, Any] | None,
    *,
    trace_sha256: str,
    allow_unverified: bool,
    schema_tables: set[str] | None = None,
) -> dict[str, Any]:
    policy = entry.get("validation", {}).get("default_execution")
    query_id = str(entry.get("id", "unknown"))
    if policy == "unsupported":
        raise RuntimeError(f"query {query_id} is unsupported")
    if policy == "require_allow_unverified":
        if not allow_unverified:
            raise RuntimeError(
                f"query {query_id} is unverified; pass --allow-unverified to proceed"
            )
        return {"status": "explicit_unverified_override", "policy": policy}
    if policy == "verified":
        return {"status": "fixture_verified", "policy": policy}
    if policy != "capability_gate_required":
        raise RuntimeError(f"query {query_id} has unknown validation policy {policy!r}")
    if not isinstance(probe, Mapping):
        raise RuntimeError(f"query {query_id} requires a trace capability probe")
    probe_trace = probe.get("trace")
    if not isinstance(probe_trace, Mapping) or probe_trace.get("sha256") != trace_sha256:
        raise RuntimeError(f"query {query_id} probe does not match the input trace")
    tables = probe.get("tables")
    if not isinstance(tables, list):
        raise RuntimeError(f"query {query_id} probe has no schema inventory")
    required_tables = {
        str(value)
        for value in entry.get("sql_dependencies", {}).get("required_tables", [])
    }
    available_tables = {str(value) for value in tables} | set(schema_tables or ())
    missing = sorted(required_tables - available_tables)
    if missing:
        raise RuntimeError(f"query {query_id} is missing required trace tables: {missing}")
    capability_inventory = probe.get("capabilities")
    required_capabilities = [
        str(value)
        for value in entry.get("compatibility", {}).get("probe_capabilities", [])
    ]
    capability_states: dict[str, str] = {}
    for capability in required_capabilities:
        state = (
            capability_inventory.get(capability, {}).get("state")
            if isinstance(capability_inventory, Mapping)
            and isinstance(capability_inventory.get(capability), Mapping)
            else None
        )
        capability_states[capability] = str(state or "unknown")
    unusable = {
        name: state
        for name, state in capability_states.items()
        if state not in {"recorded_empty", "recorded_populated"}
    }
    if unusable:
        detail = ", ".join(f"{name}={state}" for name, state in sorted(unusable.items()))
        raise RuntimeError(f"query {query_id} lacks recorded capability evidence: {detail}")
    return {
        "status": "capability_satisfied",
        "policy": policy,
        "required_tables": sorted(required_tables),
        "capabilities": capability_states,
    }
