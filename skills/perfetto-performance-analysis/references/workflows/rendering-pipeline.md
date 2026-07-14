# Rendering pipeline

## Purpose

Identify the observed rendering architecture and explain its expected threads, slices, buffers, fences, and deviation points.

## Inputs

Require a trace, target process/layer, time range, and optional architecture hypothesis.

## Availability gate

Confirm target identity and the thread/slice signals used by candidate pipeline definitions.

## Evidence sequence

Evaluate required signals, exclusions, and weighted scoring in the generated
[rendering type overview](../generated/pipelines/docs/S01_rendering_types_overview.md);
preserve competing
candidates. Load the candidate definition under `../generated/skills/`, then
verify its producer, transfer, compositor, fence, and display anchors in the
trace before using its teaching model.

## Interpretation boundaries

Detection confidence is not root-cause evidence. Thread/slice patterns may vary by Android, framework, browser, engine, and vendor version.

## Deep dives

Inspect the first late or missing producer/compositor/fence anchor using the matched pipeline's recommended evidence.

## Report requirements

Report candidate scores, matched/missing signals, selected pipeline, confidence, observed deviations, and unsupported UI-only metadata.
