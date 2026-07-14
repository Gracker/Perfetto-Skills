GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_jit_analysis.skill.yaml
Source SHA-256: 3b238fd00ac7450afc57b24ada44cbcb0b1c9f11a83cba1a91e1af48addd169a
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 启动 JIT 影响分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

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
modules: null
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
