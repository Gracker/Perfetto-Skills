GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/vsync_config.skill.yaml
Source SHA-256: 7dbf90d2995e488a38404e815e4b85f2674d51b83d6a59b78ae3ed4bcc08d946
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# VSync 配置分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: vsync_config
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: VSync 配置分析
description: 分析 VSync 周期和刷新率配置
icon: sync
tags:
- vsync
- config
- refresh_rate
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - VSync
  - 刷新率
  - vsync 周期
  - display config
  - 帧周期
  en:
  - vsync config
  - refresh rate
  - vsync period
  - display config
patterns:
- .*(VSync|vsync|刷新率|帧周期).*
- .*(vsync|refresh rate).*config.*
```

## Prerequisites

```yaml
required_tables:
- expected_frame_timeline_slice
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间（可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间（可选）
```

## Ordered execution

### 检测 Vsync 配置

- ID: `detect_vsync_config`
- Type: `atomic`
- SQL: [`../sql/vsync_config/detect_vsync_config.sql`](../sql/vsync_config/detect_vsync_config.sql)

```yaml
id: detect_vsync_config
type: atomic
save_as: vsync_config
```
## Output and evidence contract

```yaml
format: single_row
fields:
- name: vsync_period_ns
  type: integer
  description: Vsync 周期（纳秒）
- name: refresh_rate_hz
  type: number
  description: 刷新率（Hz）
- name: vsync_period_ms
  type: number
  description: Vsync 周期（毫秒）
- name: vsync_source
  type: string
  description: 数据来源
- name: detected_refresh_rate
  type: integer
  description: 检测到的刷新率
```
