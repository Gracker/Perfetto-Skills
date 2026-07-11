# CPU and scheduling

## Purpose

Explain CPU load, placement, runqueue delay, frequency, idle, IRQ, migration, and profiling behavior.

## Inputs

Require a trace, target process/threads, time range, and optional platform/topology expectations.

## Availability gate

Confirm sched events, CPU/frequency/idle counters, topology evidence, and target identity.

## Evidence sequence

Detect topology; calculate process/thread CPU time and runnable latency; inspect placement and migration; correlate frequency, idle, utilization, IRQ, and optional callstacks/perf counters. Search `references/generated/` for `cpu_analysis`, `scheduling_analysis`, and `cpu_topology_detection` after export.

## Interpretation boundaries

Do not infer capacity from CPU number or raw frequency alone. Separate CPU-bound, scheduler-bound, and supply/frequency-bound evidence.

## Deep dives

Inspect representative latency windows, wakers, affinity/uclamp evidence, IRQ pressure, and symbols when available.

## Report requirements

Report detected topology, workload scope, running/runnable time, placement/frequency evidence, alternatives, and confidence.

