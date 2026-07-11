GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/memory_pressure_in_range.skill.yaml
Source SHA-256: a66e08f21f1d0ba173f8552ced7df4ba9d4fc56822ed2b14f05d0cb93c5dfc28
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# Analyze memory pressure indicators during a specific time range.

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

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
description: Analyze memory pressure indicators in the given time range
optional: true
display:
  level: detail
  title: Memory Pressure Analysis
  columns:
  - name: pressure_level
    type: string
    description: Overall pressure level (none/low/moderate/high/critical)
  - name: pressure_score
    type: number
    description: Pressure score (0-100)
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
## Diagnostics

```yaml
- id: high_memory_pressure
  condition: pressure_score >= 40
  severity: warning
  message: '检测到内存压力 (压力分数: {pressure_score})

    - kswapd 活动: {kswapd_events} 次 ({kswapd_total_ms}ms)

    - 直接回收: {direct_reclaim_events} 次

    - 分配阻塞: {alloc_stall_events} 次

    '
  recommendation: '建议检查:

    1. 应用内存占用是否过高

    2. 是否存在内存泄漏

    3. 是否有大量临时对象分配

    '
- id: critical_memory_pressure
  condition: pressure_score >= 70 OR lmk_events > 0
  severity: critical
  message: '严重内存压力 (压力分数: {pressure_score}, LMK: {lmk_events})

    系统可能因内存不足而终止进程

    '
  recommendation: '需要立即关注:

    1. 检查是否有 OOM 或进程被杀

    2. 分析内存占用最大的进程

    3. 考虑减少内存使用或优化缓存策略

    '
- id: direct_reclaim_jank
  condition: direct_reclaim_max_ms > 5
  severity: warning
  message: '检测到直接回收导致的阻塞 (最长 {direct_reclaim_max_ms}ms)

    这可能导致帧超时或 ANR

    '
  recommendation: '建议:

    1. 减少内存分配频率

    2. 避免在关键路径上分配大对象

    3. 使用对象池复用对象'
```
