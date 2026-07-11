# Trace comparison

## Purpose

Compare two or more traces or saved evidence reports without erasing source, platform, or availability differences.

## Inputs

Require named trace sides, comparable target/scope, and either raw traces or reports that follow the public report schema.

## Availability gate

Probe and analyze each raw trace independently. Confirm metric definition, units, time window, identity, refresh rate, topology, and data-source parity before delta calculation.

## Evidence sequence

Analyze each trace independently, then apply
[multi-trace comparison](../generated/skills/multi_trace_result_comparison.md).
Build a side-by-side availability matrix, align equivalent definitions and
units, calculate bounded deltas, trace significant differences back to
side-specific evidence, and test platform, workload, and capture alternatives.

## Interpretation boundaries

Do not use frequency percent, raw duration, or missing vendor tracks as a cross-platform root cause without workload and capability context.

## Deep dives

Re-enter the relevant single-trace workflow for any side whose evidence is incomplete or whose delta lacks a mechanism.

## Report requirements

Report scope parity, availability matrix, comparable deltas, side-specific evidence refs, normalized limitations, and confidence.
