# CPU and scheduling

## Purpose

Explain CPU load, placement, runqueue delay, frequency, idle, IRQ, migration, and profiling behavior.

## Inputs

Require a trace, target process/threads, time range, and optional platform/topology expectations.

## Availability gate

Confirm sched events, CPU/frequency/idle counters, topology evidence, and target identity.

## Evidence sequence

Detect [CPU topology](../generated/skills/cpu_topology_detection.md), then run
[CPU analysis](../generated/skills/cpu_analysis.md) and
[scheduling analysis](../generated/skills/scheduling_analysis.md). Calculate
process/thread running and runnable time, placement, migration, frequency, idle,
utilization and IRQ pressure; use callstacks/perf counters only when captured.

## Interpretation boundaries

Do not infer capacity from CPU number or raw frequency alone. Separate CPU-bound, scheduler-bound, and supply/frequency-bound evidence.

## Deep dives

Inspect representative latency windows, wakers, affinity/uclamp evidence, IRQ pressure, and symbols when available.

## Report requirements

Report detected topology, workload scope, running/runnable time, placement/frequency evidence, alternatives, and confidence.
