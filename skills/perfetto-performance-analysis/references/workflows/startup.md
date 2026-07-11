# Startup

## Purpose

Explain cold, warm, or hot startup latency through trace-backed application and system evidence.

## Inputs

Require a trace, target package/process, and startup event or time range.

## Availability gate

Confirm startup tables or ActivityManager slices, process identity, thread state, and trace coverage around launch.

## Evidence sequence

Classify startup type; collect TTID/TTFD and breakdown; measure main-thread self time and states; correlate Binder, IO, class loading, GC, locks, scheduling, frequency, and first-frame production. Search `references/generated/` for `startup_analysis` and `startup_detail` after export.

## Interpretation boundaries

Do not attribute parent and child slice wall time twice. Distinguish frequency ramp delay, placement delay, thermal caps, and blocked time.

## Deep dives

Follow the strongest evidence into Binder, IO, GC, scheduling, memory pressure, rendering, or platform policy.

## Report requirements

Report startup type, timing landmarks, phase budget, root-cause chain, confidence, evidence IDs, and missing sources.

