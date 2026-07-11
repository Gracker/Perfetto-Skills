# Trace comparison

## Purpose

Compare two or more traces or saved evidence reports without erasing source, platform, or availability differences.

## Inputs

Require named trace sides, comparable target/scope, and either raw traces or reports that follow the public report schema.

## Availability gate

Probe and analyze each raw trace independently. Confirm metric definition, units, time window, identity, refresh rate, topology, and data-source parity before delta calculation.

## Evidence sequence

Build a side-by-side availability matrix; align comparable facts; calculate deltas only for equivalent metrics; trace significant differences back to side-specific evidence; test alternative platform and capture explanations. Search `references/generated/` for `multi_trace_result_comparison` after export.

## Interpretation boundaries

Do not use frequency percent, raw duration, or missing vendor tracks as a cross-platform root cause without workload and capability context.

## Deep dives

Re-enter the relevant single-trace workflow for any side whose evidence is incomplete or whose delta lacks a mechanism.

## Report requirements

Report scope parity, availability matrix, comparable deltas, side-specific evidence refs, normalized limitations, and confidence.

