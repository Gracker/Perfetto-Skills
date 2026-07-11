GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_jit_analysis.skill.yaml
Source SHA-256: 6ce25c529a4b610e61911c78f8ba61c403eb24ad58b3bec74898d6d6d35aaeb1
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 启动 JIT 影响分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_jit_analysis
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动 JIT 影响分析
description: 分析 JIT 编译线程对启动速度的影响（CPU 竞争、Code Cache GC、Baseline Profile 缺失信号）
icon: code
tags:
- startup
- jit
- compilation
- baseline_profile
- atomic
```

## Prerequisites

```yaml
modules:
- sched
```

## Inputs

```yaml
- name: package
  type: string
  required: true
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
```

## Query

Run [`../sql/startup_jit_analysis/query.sql`](../sql/startup_jit_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: JIT 影响分析
columns:
- name: metric
  label: 指标
  type: string
- name: value
  label: 值
  type: string
- name: assessment
  label: 评估
  type: string
```
