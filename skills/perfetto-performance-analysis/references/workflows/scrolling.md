# Scrolling and jank

## Purpose

Separate application frame production, compositor consumption, presentation, and missing-frame problems.

## Inputs

Require a trace, target process/layer, scroll session or time range, and expected refresh-rate context.

## Availability gate

Confirm FrameTimeline or fallback frame signals, target identity, display timing, and relevant app/SF/GPU tracks.

## Evidence sequence

Detect sessions; measure produced and presented frames; identify real, hidden, and missing jank; inspect representative frames; correlate main/RenderThread states, Binder, locks, GC, GPU, SurfaceFlinger, fences, and thermal/frequency evidence. Search `references/generated/` for `scrolling_analysis`, `scroll_session_analysis`, and `jank_frame_detail` after export.

## Interpretation boundaries

Do not equate token gaps, buffer stuffing, deadline misses, and user-visible presentation delay without checking layer and display context.

## Deep dives

Branch by detected rendering architecture and the guilty production or consumption stage.

## Report requirements

Report refresh budget, session/frame counts, representative evidence, responsibility boundary, confidence, and limitations.

