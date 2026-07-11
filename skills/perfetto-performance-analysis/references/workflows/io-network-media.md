# IO, network, and media

## Purpose

Explain filesystem/block pressure, network/modem activity, log evidence, media codecs, and WebView/V8 work.

## Inputs

Require a trace, target process, time range, and the IO, network, or media symptom.

## Availability gate

Confirm relevant ftrace/atrace/track sources, target identity, and timestamps shared with the symptom.

## Evidence sequence

Measure target file/block waits and pressure; inspect filesystem or storage activity; correlate network/modem tracks; inspect codec/media and WebView/V8 slices. Search `references/generated/` for `io_pressure`, `block_io_analysis`, `network_analysis`, and `media_codec_activity` after export.

## Interpretation boundaries

Do not infer storage, network, or codec causality from generic D-state or temporal overlap alone.

## Deep dives

Follow supported request stages, blocked functions, device activity, modem state, codec threads, or WebView architecture.

## Report requirements

Report source availability, request/stage timeline, target impact, evidence-backed mechanism, confidence, and gaps.

