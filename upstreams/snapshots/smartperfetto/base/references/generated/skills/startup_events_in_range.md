GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_events_in_range.skill.yaml
Source SHA-256: 84b7f55d58f5678da0404e8beb352a6d2fef99d23643891c09f5cc09abbf735d
# 启动事件列表 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_events_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: A
```

## Metadata

```yaml
display_name: 启动事件列表 (区间)
description: 查询启动事件及 TTID/TTFD 指标
icon: rocket_launch
tags:
- startup
- lifecycle
- atomic
```

## Prerequisites

```yaml
modules:
- android.startup.startups
- android.startup.time_to_display
- android.startup.startup_events
```

## Inputs

```yaml
- name: package
  type: string
  required: false
- name: startup_id
  type: integer
  required: false
- name: startup_type
  type: string
  required: false
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Query

Run [`../sql/startup_events_in_range/query.sql`](../sql/startup_events_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: overview
title: 检测到的启动事件
columns:
- name: startup_id
  label: 启动 ID
  type: number
- name: upid
  label: UPID
  type: number
  hidden: true
- name: package
  label: 包名
  type: string
- name: type_display
  label: 启动类型
  type: string
- name: dur_ms
  label: 耗时
  type: duration
  format: duration_ms
  unit: ms
- name: start_ts
  label: 开始时间
  type: timestamp
  unit: ns
  clickAction: navigate_range
  durationColumn: dur_ns
- name: end_ts
  label: 结束时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
- name: dur_ns
  label: 耗时(ns)
  type: duration
  format: duration_ms
  unit: ns
  hidden: true
- name: dur_without_trampoline_ms
  label: 去 Trampoline 耗时
  type: duration
  format: duration_ms
  unit: ms
- name: trampoline_ms
  label: Trampoline 耗时
  type: duration
  format: duration_ms
  unit: ms
- name: ttid_ms
  label: TTID
  type: duration
  format: duration_ms
  unit: ms
- name: ttfd_ms
  label: TTFD
  type: duration
  format: duration_ms
  unit: ms
- name: rating
  label: 评级
  type: string
- name: original_type
  label: Stdlib 类型
  label_i18n:
    en: Stdlib type
  type: string
- name: stdlib_platform_marker
  label: 匹配的平台启动类型标记
  label_i18n:
    en: Matched platform startup type marker
  type: string
- name: classification_basis
  label: Skill 分类依据
  label_i18n:
    en: Skill classification basis
  type: string
- name: bind_app_start_ts
  label: bindApplication 开始
  label_i18n:
    en: bindApplication start
  type: timestamp
  unit: ns
  hidden: true
- name: bind_app_end_ts
  label: bindApplication 结束
  label_i18n:
    en: bindApplication end
  type: timestamp
  unit: ns
  hidden: true
- name: process_start_ts
  label: 进程创建时间
  label_i18n:
    en: Process creation time
  type: timestamp
  unit: ns
  hidden: true
- name: process_first_state_ts
  label: 进程首个线程状态观测
  label_i18n:
    en: First observed process thread state
  type: timestamp
  unit: ns
  hidden: true
- name: first_state_before_start_ms
  label: 首个状态早于启动
  label_i18n:
    en: First state before startup
  type: number
  unit: ms
- name: type_reclassified
  label: 类型已修正
  type: number
  hidden: true
- name: type_confidence
  label: 分类置信度
  type: string
```
