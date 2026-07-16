GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/memory_rss_high_watermark.skill.yaml
Source SHA-256: 4cf80939e6b952de97407a954e1b420e4a2e52e02330c003a6cd1fa148a49cd7
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 进程 RSS 内存峰值

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: memory_rss_high_watermark
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: 进程 RSS 内存峰值
description: 每进程 RSS 内存最高水位（高内存 = 风险源头）
icon: memory
tags:
- memory
- rss
- watermark
- atomic
```

## Prerequisites

```yaml
modules:
- linux.memory.high_watermark
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
- name: top_n
  type: number
  required: false
  default: 30
```

## Ordered execution

### RSS 内存峰值排行

- ID: `rss_peaks`
- Type: `atomic`
- SQL: [`../sql/memory_rss_high_watermark/rss_peaks.sql`](../sql/memory_rss_high_watermark/rss_peaks.sql)

```yaml
id: rss_peaks
type: atomic
display:
  level: detail
  layer: list
  title: Top RSS 占用进程
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: rss_high_watermark_kb
    label: RSS 峰值(KB)
    type: bytes
    format: compact
```
