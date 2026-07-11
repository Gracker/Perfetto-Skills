GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_binder_pool_analysis.skill.yaml
Source SHA-256: 6f1f394a97708c7e21b8372f5891316858b397cd37477cba43d7fa54adf9fb1f
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# Binder 线程池分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_binder_pool_analysis
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: Binder 线程池分析
description: 分析启动期间 Binder 线程池利用率和饱和度
icon: dns
tags:
- startup
- binder
- thread_pool
- saturation
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

Run [`../sql/startup_binder_pool_analysis/query.sql`](../sql/startup_binder_pool_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: Binder 线程池分析
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
