# Trace overview

## Purpose

Establish trace health, bounds, identity, and available evidence before domain analysis.

## Inputs

Require one trace and optional process, thread, or time-range targets.

## Availability gate

Run the probe script. Confirm trace bounds, metadata, process/thread tables, and requested scope.

## Evidence sequence

Run [global trace sanity](../generated/skills/global_trace_sanity_check.md),
[process identity resolution](../generated/skills/process_identity_resolver.md),
and [device state](../generated/skills/device_state_snapshot.md). Save the probe,
trace hash/bounds, selected identities, availability matrix, and routing facts
before any domain query.

## Interpretation boundaries

Do not treat absent tracks as absent system behavior until capture support is proven.

## Deep dives

Route each verified anomaly to the narrowest domain workflow.

## Bounded closing sweep

The following structured block is the source of truth for this workflow's
closing behavior:

```json analysis-closure-contract
{
  "applies_to": "open_ended_investigation",
  "max_secondary_domains": 3,
  "report_fields": [
    "checked_domains",
    "missing_data",
    "unresolved_alternatives"
  ],
  "skip_for": "bounded_question",
  "stop_conditions": [
    "no_independent_high_impact_anomaly",
    "repeated_evidence",
    "missing_data",
    "budget_exhausted"
  ]
}
```

For an open-ended investigation, run one secondary sweep after the primary
evidence chain. Select at most three still-unchecked domains from signals that
are both observed and available in this trace. Stop when no independent
high-impact anomaly is found, the next query would already repeat evidence,
required data is unavailable, or the query budget is exhausted.

Do not add this sweep to a specific bounded question. An empty secondary sweep
does not weaken a verified primary finding. Record the checked domains, missing
data, and unresolved alternatives in the report.

## Report requirements

Report trace identity, bounds, available/missing sources, selected target, and routing decision.
