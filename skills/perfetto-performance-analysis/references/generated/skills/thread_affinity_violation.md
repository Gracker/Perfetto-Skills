GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/thread_affinity_violation.skill.yaml
Source SHA-256: 8b1f713a09cd8c1f1725b590ab20764687be3783a8ff9004606bbd80927bfecb
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 线程亲和性异常

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thread_affinity_violation
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: 线程亲和性异常
description: 检测主线程/RenderThread 的高频迁核行为
icon: compare_arrows
tags:
- cpu
- affinity
- scheduler
- migration
```

## Triggers

```yaml
keywords:
  zh:
  - 迁核
  - 亲和性
  - 调度抖动
  - 大小核
  - CPU 绑定
  en:
  - migration
  - affinity
  - scheduler jitter
  - core pinning
patterns:
- .*(thread|main|render).*(migration|affinity).*
- .*(迁核|亲和性|调度).*
```

## Prerequisites

```yaml
required_tables:
- sched
- thread
- process
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名(可选)
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
- name: migration_ratio_threshold
  type: number
  required: false
  default: 25
  description: 迁核占比阈值(%)
```

## Query

Run [`../sql/thread_affinity_violation/query.sql`](../sql/thread_affinity_violation/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 线程亲和性
columns:
- name: process_name
  label: 进程
  type: string
- name: thread_name
  label: 线程
  type: string
- name: run_samples
  label: 运行样本
  type: number
- name: distinct_cpus
  label: 涉及 CPU 数
  type: number
- name: migration_count
  label: 迁核次数
  type: number
- name: migration_ratio_pct
  label: 迁核占比
  type: percentage
  format: percentage
- name: affinity_violation
  label: 亲和性异常
  type: boolean
```
