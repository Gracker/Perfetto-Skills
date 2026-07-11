# IO, network, and media

## Purpose

Explain filesystem/block pressure, network/modem activity, log evidence, media codecs, and WebView/V8 work.

## Inputs

Require a trace, target process, time range, and the IO, network, or media symptom.

## Availability gate

Confirm relevant ftrace/atrace/track sources, target identity, and timestamps shared with the symptom.

## Evidence sequence

Measure target waits with [IO pressure](../generated/skills/io_pressure.md) and
[block IO analysis](../generated/skills/block_io_analysis.md), resolving
blocked functions and device activity. Branch to
[network analysis](../generated/skills/network_analysis.md), modem tracks,
[media codec activity](../generated/skills/media_codec_activity.md), or WebView/V8
only when those signals overlap the same target and symptom interval.

## Interpretation boundaries

Do not infer storage, network, or codec causality from generic D-state or temporal overlap alone.

## Deep dives

Follow supported request stages, blocked functions, device activity, modem state, codec threads, or WebView architecture.

## Report requirements

Report source availability, request/stage timeline, target impact, evidence-backed mechanism, confidence, and gaps.
