# Trace overview

## Purpose

Establish trace health, bounds, identity, and available evidence before domain analysis.

## Inputs

Require one trace and optional process, thread, or time-range targets.

## Availability gate

Run the probe script. Confirm trace bounds, metadata, process/thread tables, and requested scope.

## Evidence sequence

Collect global sanity, device state, process identity, state tracks, system load, and data-source availability. Search `references/generated/` for `global_trace_sanity_check`, `process_identity_resolver`, and `device_state_snapshot` after export.

## Interpretation boundaries

Do not treat absent tracks as absent system behavior until capture support is proven.

## Deep dives

Route each verified anomaly to the narrowest domain workflow.

## Report requirements

Report trace identity, bounds, available/missing sources, selected target, and routing decision.

