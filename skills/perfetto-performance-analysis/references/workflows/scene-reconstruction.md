# Scene reconstruction

## Purpose

Reconstruct an evidence-backed event sequence across domains when the symptom does not map cleanly to one metric.

## Inputs

Require a trace, target process or user-visible event, and a bounded time range.

## Availability gate

Complete trace overview, target identity, time bounds, and architecture detection before cross-domain reconstruction.

## Evidence sequence

Build ordered landmarks with [scene reconstruction](../generated/skills/scene_reconstruction.md)
and [state timeline](../generated/skills/state_timeline.md). Group app,
framework, kernel, hardware, and display observations by stable identity and
interval; test alternatives; deepen only gaps that can change the conclusion.

## Interpretation boundaries

An ordered narrative is not automatically causal. Every link must carry identity, interval, evidence class, and uncertainty.

## Deep dives

Route unresolved gaps to lifecycle, interaction, blocking, CPU, memory, rendering, IO, or power workflows.

## Report requirements

Report the timeline, verified links, rejected alternatives, unresolved gaps, evidence IDs, and confidence per link.
