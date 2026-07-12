GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/vsync_period_detection.skill.yaml
Source SHA-256: 870926eca37f73c608893a33deede62d63caf3290a3d7aca13d080e61e764f68
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# Detect VSync period from trace data using median of VSYNC-sf intervals.

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: vsync_period_detection
version: 1.0.0
type: atomic
category: frame
tier: B
description: 'Detect VSync period from trace data using median of VSYNC-sf intervals.

  Returns detected period, refresh rate (computed dynamically), and confidence score.

  '
tags:
- vsync
- refresh_rate
- frame_timing
- detection
```

## Prerequisites

```yaml
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: start_ts
  type: number
  required: false
  description: Start timestamp (ns) - optional filter
- name: end_ts
  type: number
  required: false
  description: End timestamp (ns) - optional filter
```

## Ordered execution

### detect_vsync_period

- ID: `detect_vsync_period`
- Type: `atomic`
- SQL: [`../sql/vsync_period_detection/detect_vsync_period.sql`](../sql/vsync_period_detection/detect_vsync_period.sql)

```yaml
id: detect_vsync_period
description: Detect VSync period using multiple data sources
display:
  level: summary
  title: VSync Period Detection
  columns:
  - name: vsync_period_ns
    type: number
    description: Detected VSync period in nanoseconds
  - name: detected_refresh_rate_hz
    type: number
    description: Detected display refresh rate in Hz
  - name: measured_period_ns
    type: number
    description: Raw measured period before snapping
  - name: detection_method
    type: string
    description: Method used for detection (vsync_sf, frame_timeline, default)
  - name: confidence
    type: number
    description: Confidence score (0-1)
  - name: sample_count
    type: number
    description: Number of samples used for detection
  - name: theoretical_fps
    type: number
    description: Theoretical max FPS based on refresh rate
```
