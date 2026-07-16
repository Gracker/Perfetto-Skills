GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/memory_growth_detector.skill.yaml
Source SHA-256: d088a4f84486f3486d78bca495692f08bcfb5082ca1116aa968809851ef1873d
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 内存增长检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: memory_growth_detector
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: 内存增长检测
description: 基于 linux.memory.process stdlib 按 UPID 比较 RSS/Swap 趋势、跳跃和峰均异常
icon: trending_up
tags:
- memory
- rss
- swap
- growth
- leak
- runtime
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 内存增长
  - 内存泄漏
  - RSS 增长
  - swap 增长
  - 泄漏检测
  en:
  - memory growth
  - memory leak
  - rss growth
  - swap growth
  - leak detection
patterns:
- .*(内存|RSS|swap).*(增长|泄漏).*
- .*(memory|rss|swap).*(growth|leak).*
```

## Prerequisites

```yaml
modules:
- linux.memory.process
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: growth_warning_mb
  type: number
  required: false
  default: 50
  description: 增长告警阈值(MB)，默认 50
- name: growth_pct_min_mb
  type: number
  required: false
  default: 5
  description: 百分比增长触发评级所需的最小 RSS 增长(MB)，默认 5
- name: growth_warning_pct
  type: number
  required: false
  default: 20
  description: RSS 增长率关注阈值(%)，默认 20
- name: growth_critical_pct
  type: number
  required: false
  default: 50
  description: RSS 增长率严重阈值(%)，默认 50
- name: jump_warning_mb
  type: number
  required: false
  default: 10
  description: 相邻采样 RSS 跳跃阈值(MB)，默认 10
- name: peak_avg_warning_ratio
  type: number
  required: false
  default: 2
  description: Peak/Avg 异常阈值，默认 2
```

## Ordered execution

### 进程内存增长

- ID: `memory_growth`
- Type: `atomic`
- SQL: [`../sql/memory_growth_detector/memory_growth.sql`](../sql/memory_growth_detector/memory_growth.sql)

```yaml
id: memory_growth
type: atomic
display:
  level: summary
  layer: overview
  title: 进程内存增长检测
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: pid
    label: PID
    type: number
  - name: samples
    label: 样本数
    type: number
    format: compact
  - name: duration_s
    label: 时长(s)
    type: number
  - name: first_rss_mb
    label: 初始RSS(MB)
    type: number
  - name: last_rss_mb
    label: 结束RSS(MB)
    type: number
  - name: rss_growth_mb
    label: RSS增长(MB)
    type: number
  - name: rss_growth_pct
    label: RSS增长率
    type: percentage
    format: percentage
  - name: rss_slope_mb_s
    label: RSS斜率(MB/s)
    type: number
  - name: max_single_jump_mb
    label: 最大跳跃(MB)
    type: number
  - name: max_rss_mb
    label: RSS峰值(MB)
    type: number
  - name: avg_rss_mb
    label: 加权平均RSS(MB)
    type: number
  - name: peak_avg_ratio
    label: Peak/Avg
    type: number
  - name: max_anon_ratio_pct
    label: Anon+Swap/RSS峰值
    type: percentage
    format: percentage
  - name: swap_growth_mb
    label: Swap增长(MB)
    type: number
  - name: rating
    label: 评级
    type: string
save_as: memory_growth
```
## Output and evidence contract

```yaml
format: structured
```
