# GPU and rendering

## Purpose

Explain application rendering, GPU work, SurfaceFlinger consumption/composition, fences, refresh behavior, and presentation delay.

## Inputs

Require a trace, target process/layer, frame or time range, and display context.

## Availability gate

Confirm app/SF frame signals, GPU tracks or counters, fence data, refresh-rate evidence, and target layer identity.

## Evidence sequence

Measure app production and SF consumption; inspect GPU work/frequency/power state; decompose acquire/present/release fence waits; check composition path, buffer lifecycle, VRR, and presentation. Search `references/generated/` for `gpu_analysis`, `surfaceflinger_analysis`, and `fence_wait_decomposition` after export.

## Interpretation boundaries

Do not assign GPU responsibility from long app frames without GPU evidence. Keep producer, consumer, compositor, HWC, and display boundaries distinct.

## Deep dives

Follow the detected pipeline and the first verified late anchor or fence.

## Report requirements

Report pipeline stage, layer/frame identity, late interval, supported responsibility, evidence IDs, and limitations.

