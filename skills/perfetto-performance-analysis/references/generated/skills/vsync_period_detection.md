GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/vsync_period_detection.skill.yaml
Source SHA-256: b6139b2a252fbc4644978e6801b666ac16d081516ec77a75c8cb3d86da538043
Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49
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
type: atomic
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
