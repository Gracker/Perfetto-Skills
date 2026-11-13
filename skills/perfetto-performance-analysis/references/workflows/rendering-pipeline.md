# Rendering pipeline

## Purpose

Identify the observed rendering architecture and explain its expected threads, slices, buffers, fences, and deviation points.

## Inputs

Require a trace, target process/layer, time range, and optional architecture hypothesis.

## Availability gate

Confirm target identity and the thread/slice signals used by candidate pipeline definitions.

## Evidence sequence

Run `rendering_pipeline_detection` with the confirmed target and time range.
Evaluate required signals, exclusions, and weighted scores; preserve competing
candidates and an unconfirmed result when required evidence is absent. Version
aliases in `slice_patterns` form one OR signal: overlapping names do not add
weight or duplicate matching events.

Read the candidate definition under `../generated/skills/` and the corresponding
type in the local [product teaching cards](../generated/knowledge/rendering-teaching.md).
The detector's `doc_path` identifies that bundled reference from the Skill root.
Verify producer, transfer, compositor, fence, and display anchors against the
same object and time range. Cards describe reference topology; temporal
adjacency alone does not establish a causal handoff.

## Interpretation boundaries

Detection confidence is not root-cause evidence. Thread/slice patterns may vary by Android, framework, browser, engine, and vendor version.

Functor sync, post-draw, initialization, or reparenting is not proof of a draw.
A JavaScript thread alone does not establish React Native Paper or Fabric.
BufferTX pending updates count received/removed work, not displayed frames;
decreases may include drops. Missing FrameTimeline or Fence evidence does not
establish smoothness or GPU readiness.

## Deep dives

Inspect the first late or missing producer/compositor/fence anchor using the matched pipeline's recommended evidence.

## Report requirements

Report candidate scores, matched/missing signals, selected pipeline, confidence, observed deviations, and unsupported UI-only metadata.
