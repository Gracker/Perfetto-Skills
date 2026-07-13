GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/logcat_analysis.skill.yaml
Source SHA-256: 8c0018e6416eba29e18bcde7319b929fcc73db350ceff3d87b86e2e2b66e0f60
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# Logcat 异常信号检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: logcat_analysis
version: '1.0'
type: atomic
category: system
tier: B
```

## Metadata

```yaml
display_name: Logcat 异常信号检测
description: 检测 trace 期间的 Logcat 中 ANR/GC/Binder/StrictMode 等关键系统警告
icon: warning
tags:
- logcat
- anr
- gc
- binder
- warning
- atomic
```

## Prerequisites

```yaml
required_tables:
- android_logs
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 目标进程名
```

## Query

Run [`../sql/logcat_analysis/query.sql`](../sql/logcat_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: summary
layer: overview
title: Logcat 异常信号
columns:
- name: ts_str
  label: 时间
  type: string
- name: prio
  label: 优先级
  type: string
- name: tag
  label: Tag
  type: string
- name: signal_type
  label: 信号类型
  type: string
- name: evidence_scope
  label: 证据范围
  type: string
- name: msg_preview
  label: 消息
  type: string
```
