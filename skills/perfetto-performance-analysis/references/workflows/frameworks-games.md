# Frameworks and games

## Purpose

Apply architecture-specific evidence to Compose, Flutter, React Native, WebView, games, and vendor scheduling signals.

## Inputs

Require a trace, target process, frame/session or time range, and suspected framework only as a hypothesis.

## Availability gate

Detect architecture from trace signals before loading a framework branch; confirm its threads/slices and general frame evidence.

## Evidence sequence

Run generic frame and scheduler checks first; then inspect Compose recomposition, Flutter UI/raster/Impeller/Skia, React Native bridge/Fabric/Skia, game loops, FPSGO, or vendor tracks. Search `references/generated/` for `compose_recomposition_hotspot`, `flutter_scrolling_analysis`, `rn_fabric_render_jank`, and `game_fps_analysis` after export.

## Interpretation boundaries

Treat thread and slice names as version/vendor signals, not stable APIs. Fall back to generic evidence when architecture confidence is low.

## Deep dives

Follow the verified framework stage, engine loop, bridge, raster/GPU path, or platform policy decision.

## Report requirements

Report detection signals/confidence, generic versus architecture-specific evidence, version limits, and recommendations.

