# Scrolling and jank

## Purpose

Separate application frame production, compositor consumption, presentation, and missing-frame problems.

## Inputs

Require a trace, target process/layer, scroll session or time range, and expected refresh-rate context.

## Availability gate

Confirm FrameTimeline or independently identified frame evidence, target identity,
display timing, and relevant app/SF/GPU tracks. Treat BufferTX as SF-side pending
buffer-update evidence. Its presence cannot restore missing frame or FPS evidence.

## Evidence sequence

Run [scrolling analysis](../generated/skills/scrolling_analysis.md) and
[session analysis](../generated/skills/scroll_session_analysis.md). Measure
produced and presented frames separately, identify real, hidden, and missing
jank, then use [frame detail](../generated/skills/jank_frame_detail.md) on
representative frames across main/RenderThread, Binder, locks, GC, GPU,
SurfaceFlinger, fences, and thermal/frequency evidence.

## Interpretation boundaries

Do not equate token gaps, buffer stuffing, deadline misses, and user-visible presentation delay without checking layer and display context.

Report BufferTX positive deltas as received buffer updates, with their observation
span and update rate. Keep frame count, FPS, and jank metrics unknown when that is
the only available source; preserve SQL NULL values rather than filling them with
zero. A pending decrease can reflect latch or drop. Neither direction proves GPU
readiness or presentation, and matching a layer name does not establish exact
process-instance identity.

Use the FrameTimeline-to-BufferTX source-event ratio only as a heuristic. The two
sources describe different populations; a ratio above one does not prove dropped
BufferTX observations, and no ratio establishes full FrameTimeline coverage.
Analyze observed FrameTimeline samples independently without extrapolating a
complete frame count or root-cause distribution.

Follow buffer, layer, transaction, and frame identities when relating stages.
Without those links, report queue-to-transaction and transaction-to-latch latency
as unavailable. Do not pair a queue event with the next global SF event. Global SF
activity and package-selected application events retain separate attribution.

## Deep dives

Branch by detected rendering architecture and the guilty production or consumption stage.

## Report requirements

Report refresh budget, measured session/frame counts, representative evidence,
responsibility boundary, confidence, and limitations. Identify received-update
metrics separately from frame metrics and make missing evidence explicit.
