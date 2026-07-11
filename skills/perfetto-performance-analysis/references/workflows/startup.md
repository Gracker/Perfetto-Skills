# Startup

## Purpose

Explain cold, warm, or hot startup latency through trace-backed application and system evidence.

## Inputs

Require a trace, target package/process, and startup event or time range.

## Availability gate

Confirm startup tables or ActivityManager slices, process identity, thread state, and trace coverage around launch.

## Evidence sequence

Run [startup analysis](../generated/skills/startup_analysis.md), then the bounded
[startup detail](../generated/skills/startup_detail.md). Preserve cold/warm/hot
classification and TTID/TTFD landmarks; attribute phases with self time; measure
main-thread states; then test Binder, IO, class loading/JIT, GC, locks,
scheduling, frequency ramp, memory pressure, and first-frame production.

## Interpretation boundaries

Do not attribute parent and child slice wall time twice. Distinguish frequency ramp delay, placement delay, thermal caps, and blocked time.

## Deep dives

Follow the strongest evidence into Binder, IO, GC, scheduling, memory pressure, rendering, or platform policy.

## Report requirements

Report startup type, timing landmarks, phase budget, root-cause chain, confidence, evidence IDs, and missing sources.
