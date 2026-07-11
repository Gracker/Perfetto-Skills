# Memory and GC

## Purpose

Explain memory growth, pressure, GC impact, heap retention candidates, LMK, DMA-BUF, RSS, and native allocation.

## Inputs

Require a trace, target process, time range, and the requested memory symptom.

## Availability gate

Confirm available counters, heap graph/heapprofd data, GC slices, LMK events, DMA-BUF data, and target identity.

## Evidence sequence

Build trends with [memory analysis](../generated/skills/memory_analysis.md),
separating Java, native, graphics, file, swap, and system pressure. Inspect pause
and churn with [GC analysis](../generated/skills/gc_analysis.md); branch to
[LMK attribution](../generated/skills/lmk_analysis.md), DMA-BUF, heap graph,
native allocation, or RSS evidence only when its source is available.

## Interpretation boundaries

Do not call growth a leak without retention evidence. Separate unreleased retention, allocation churn, cache growth, pressure, and missing sources.

## Deep dives

Use heap graph, native allocation, process RSS/swap, bitmap, DMA-BUF, and LMK branches only when their data sources exist.

## Report requirements

Report component trends, GC/pressure overlap, retention or churn evidence, confidence, and unavailable memory sources.
