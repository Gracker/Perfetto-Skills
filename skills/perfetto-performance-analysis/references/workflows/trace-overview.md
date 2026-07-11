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

## Report requirements

Report trace identity, bounds, available/missing sources, selected target, and routing decision.
