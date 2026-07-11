# Trace comparison

## Purpose

Compare two or more traces or saved evidence reports without erasing source, platform, or availability differences.

## Inputs

Require named trace sides, comparable target/scope, and either raw traces or
file-based side summaries that follow
[`comparison-input-schema.json`](../../assets/comparison-input-schema.json).

## Availability gate

Probe and analyze each raw trace independently. Confirm metric definition, units, time window, identity, refresh rate, topology, and data-source parity before delta calculation.

## Evidence sequence

Analyze each trace independently and write one side-summary JSON per trace. Use
the portable [comparison adapter](../generated/skills/multi_trace_result_comparison.md):
`python3 <skill-root>/scripts/perfetto_compare.py --side baseline=a.json --side
candidate=b.json --baseline baseline`. It builds the availability matrix and
computes deltas only when definitions, units, and observed states match. Trace
significant differences back to side-specific evidence and test platform,
workload, and capture alternatives.

## Interpretation boundaries

Do not use frequency percent, raw duration, or missing vendor tracks as a cross-platform root cause without workload and capability context.

## Deep dives

Re-enter the relevant single-trace workflow for any side whose evidence is incomplete or whose delta lacks a mechanism.

## Report requirements

Report scope parity, availability matrix, comparable deltas, side-specific evidence refs, normalized limitations, and confidence.
