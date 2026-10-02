GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/memory_pressure_in_range.skill.yaml
Source SHA-256: 1d1b1b7b513c1ebbeb083c893261b659bc336ab81d34c49d025e7421e80a3976
# Analyze memory pressure indicators during a specific time range.

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: memory_pressure_in_range
version: 1.0.0
type: atomic
category: memory
tier: A
description: 'Analyze memory pressure indicators during a specific time range.

  Detects PSI metrics, kswapd activity, direct reclaim, and LMK events

  that may contribute to jank or performance issues.

  '
tags:
- memory
- pressure
- psi
- kswapd
- reclaim
- lmk
- range_based
```

## Inputs

```yaml
- name: start_ts
  type: number
  required: true
  description: Start timestamp in nanoseconds
- name: end_ts
  type: number
  required: true
  description: End timestamp in nanoseconds
- name: package
  type: string
  required: false
  description: Package name to filter (optional)
```

## Ordered execution

### memory_pressure_analysis

- ID: `memory_pressure_analysis`
- Type: `atomic`
- SQL: [`../sql/memory_pressure_in_range/memory_pressure_analysis.sql`](../sql/memory_pressure_in_range/memory_pressure_analysis.sql)

```yaml
id: memory_pressure_analysis
type: atomic
description: Analyze memory pressure indicators in the given time range
optional: true
display:
  level: detail
  title: Memory Pressure Analysis
  columns:
  - name: psi_max
    type: number
    description: Maximum sample value from a single PSI track
  - name: psi_avg
    type: number
    description: Arithmetic sample mean from a single PSI track
  - name: psi_sample_count
    type: number
  - name: psi_metric_count
    type: number
  - name: psi_metric_names
    type: string
  - name: psi_aggregation_basis
    type: string
  - name: censored_event_count
    type: number
  - name: duration_basis
    type: string
  - name: pressure_basis
    type: string
  - name: pressure_level
    type: string
    description: Overall pressure level (none/low/moderate/high/critical)
  - name: pressure_score
    type: number
    description: Heuristic weighted event score; not a calibrated probability
  - name: kswapd_events
    type: number
    description: Number of kswapd activities
  - name: kswapd_total_ms
    type: duration
    format: duration_ms
    description: Total kswapd activity time
  - name: direct_reclaim_events
    type: number
    description: Number of direct reclaim events
  - name: direct_reclaim_max_ms
    type: duration
    format: duration_ms
    description: Max direct reclaim duration
  - name: lmk_events
    type: number
    description: Number of LMK events
  - name: alloc_stall_events
    type: number
    description: Number of allocation stalls
  - name: page_cache_add_events
    type: number
    description: Page cache adds (mm_filemap_add_to_page_cache = cache miss, disk read)
  - name: page_cache_delete_events
    type: number
    description: Page cache evictions (mm_filemap_delete_from_page_cache = memory pressure)
```
