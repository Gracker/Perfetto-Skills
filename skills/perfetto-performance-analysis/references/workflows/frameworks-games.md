# Frameworks and games

## Purpose

Apply architecture-specific evidence to Compose, Flutter, React Native, WebView, games, and vendor scheduling signals.

## Inputs

Require a trace, target process, frame/session or time range, and suspected framework only as a hypothesis.

## Availability gate

Detect architecture from trace signals before loading a framework branch; confirm its threads/slices and general frame evidence.

## Evidence sequence

Run generic frame and scheduler checks first. After architecture detection, load
only the matching branch: [Compose recomposition](../generated/skills/compose_recomposition_hotspot.md),
[Flutter scrolling](../generated/skills/flutter_scrolling_analysis.md),
[React Native Fabric](../generated/skills/rn_fabric_render_jank.md), or
[game FPS](../generated/skills/game_fps_analysis.md), plus relevant engine,
FPSGO, and vendor tracks.

## Interpretation boundaries

Treat thread and slice names as version/vendor signals, not stable APIs. Fall back to generic evidence when architecture confidence is low.

## Deep dives

Follow the verified framework stage, engine loop, bridge, raster/GPU path, or platform policy decision.

## Report requirements

Report detection signals/confidence, generic versus architecture-specific evidence, version limits, and recommendations.
