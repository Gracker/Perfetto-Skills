# Interaction and navigation

## Purpose

Measure touch, click, input dispatch, application response, navigation, and first resulting frame.

## Inputs

Require a trace, target process, interaction event or selection range, and expected response surface.

## Availability gate

Confirm input events or atrace fallbacks, target threads, lifecycle/slice signals, and frame evidence.

## Evidence sequence

Build input-to-handler-to-work-to-frame landmarks; quantify gaps; inspect target thread states, Binder/lock/IO/GC work, render production, and presentation. Search `references/generated/` for `click_response_analysis`, `touch_to_display_latency`, and `navigation_analysis` after export.

## Interpretation boundaries

Do not infer input dispatch latency from frame delay alone or assign app responsibility for system-side presentation delay.

## Deep dives

Route handler, lifecycle, scheduler, Binder, IO, or rendering gaps to their domain evidence.

## Report requirements

Report the complete landmark timeline, missing landmarks, largest verified gap, evidence IDs, and confidence.

