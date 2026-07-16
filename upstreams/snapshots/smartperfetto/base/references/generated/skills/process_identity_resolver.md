GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/process_identity_resolver.skill.yaml
Source SHA-256: 0825f2ccd3b390e08777718e3eab70f65d0c162625007baded0f9cc0093a8500
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 进程身份交叉解析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: process_identity_resolver
version: '1.0'
type: atomic
category: system
tier: A
```

## Metadata

```yaml
display_name: 进程身份交叉解析
description: 交叉 process、android_process_metadata、cmdline、线程名、FrameTimeline layer、OOM adj 和 battery_stats.top，确认下游 Skill 应使用的真实
  process.name
icon: badge
tags:
- system
- process
- identity
- package
- upid
- thread
- android
```

## Triggers

```yaml
keywords:
  zh:
  - 进程身份
  - 进程名
  - 包名
  - upid
  - 线程名
  - process identity
  - 进程名不对
  - 包名不对
  en:
  - process identity
  - process name
  - package name
  - upid
  - thread name
  - wrong process
patterns:
- .*(进程名|包名).*(不对|错误|错|冲突).*
- .*process.*(identity|name).*
- .*package.*(identity|name).*
```

## Prerequisites

```yaml
modules:
- android.process_metadata
- android.frames.timeline
- android.oom_adjuster
- android.battery_stats
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 用户期望的 Android 包名或进程名前缀
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: thread_name
  type: string
  required: false
  description: 可选线程名线索，例如 main、RenderThread、1.ui、CrRendererMain
- name: upid
  type: integer
  required: false
  description: 已知 trace 内唯一进程 ID；优先级最高
- name: pid
  type: integer
  required: false
  description: 已知 OS 进程 ID；仅作为辅助线索，PID 可能复用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)，默认 trace_start()
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)，默认 trace_end()
- name: max_rows
  type: integer
  required: false
  default: 20
  description: 最多返回候选进程数
```

## Identity requirements

```yaml
policy: exempt
scope: process
```

## Query

Run [`../sql/process_identity_resolver/query.sql`](../sql/process_identity_resolver/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
primary_metric: confidence_score
```

## Display metadata

```yaml
level: key
layer: overview
title: 进程身份候选
columns:
- name: rank
  label: Rank
  type: number
- name: confidence_score
  label: 置信分
  type: number
- name: identity_status
  label: 状态
  type: string
- name: canonical_package_name
  label: 规范包名
  type: string
  format: truncate
- name: recommended_process_name_param
  label: 传给 process_name
  type: string
  format: truncate
- name: upid
  label: UPID
  type: number
- name: pid
  label: PID
  type: number
- name: process_name
  label: process.name
  type: string
  format: truncate
- name: metadata_process_name
  label: metadata.process
  type: string
  format: truncate
- name: package_name
  label: metadata.package
  type: string
  format: truncate
- name: cmdline
  label: cmdline
  type: string
  format: truncate
- name: target_match_sources
  label: 命中来源
  type: string
  format: truncate
- name: supporting_sources
  label: 辅助证据
  type: string
  format: truncate
- name: frame_rows
  label: Frame 行
  type: number
- name: jank_rows
  label: Jank 行
  type: number
- name: foreground_ms
  label: 前台 OOM(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: battery_top_ms
  label: Battery Top(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: thread_count
  label: 线程数
  type: number
- name: key_thread_names
  label: 关键线程
  type: string
  format: truncate
- name: thread_utid
  label: 命中线程 UTID
  type: number
- name: thread_tid
  label: 命中线程 TID
  type: number
- name: thread_name
  label: 命中线程
  type: string
  format: truncate
- name: thread_role
  label: 线程角色
  type: string
- name: thread_target_matched
  label: 命中目标线程
  type: boolean
- name: layer_packages
  label: Layer 包名
  type: string
  format: truncate
- name: identity_warning
  label: 风险提示
  type: string
  format: truncate
```
