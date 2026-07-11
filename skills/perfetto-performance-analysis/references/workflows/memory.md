# Memory and GC

## Purpose

Explain memory growth, pressure, GC impact, heap retention candidates, LMK, DMA-BUF, RSS, and native allocation.

## Inputs

Require a trace, target process, time range, and the requested memory symptom.

## Availability gate

Confirm available counters, heap graph/heapprofd data, GC slices, LMK events, DMA-BUF data, and target identity.

## Evidence sequence

Build memory trends; separate Java, native, graphics, file, swap, and system pressure; inspect GC pause/churn; analyze LMK or retention evidence; correlate with target symptoms. Search `references/generated/` for `memory_analysis`, `gc_analysis`, `lmk_analysis`, and `dmabuf_analysis` after export.

## Interpretation boundaries

Do not call growth a leak without retention evidence. Separate unreleased retention, allocation churn, cache growth, pressure, and missing sources.

## Deep dives

Use heap graph, native allocation, process RSS/swap, bitmap, DMA-BUF, and LMK branches only when their data sources exist.

## Report requirements

Report component trends, GC/pressure overlap, retention or churn evidence, confidence, and unavailable memory sources.

