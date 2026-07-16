GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_freq_rampup.skill.yaml
Source SHA-256: 5fdc44a881eba8aac3be4fc8cc7f6175bd41bc13c9a6fc164f19ec3b4bda8f28
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 启动 CPU 频率爬升

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_freq_rampup
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动 CPU 频率爬升
description: 分析冷启动初期 CPU 频率爬升速度，检测升频延迟
icon: speed
tags:
- startup
- cpu
- frequency
- rampup
- governor
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
```

## Query

Run [`../sql/startup_freq_rampup/query.sql`](../sql/startup_freq_rampup/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: CPU 频率爬升分析
columns:
- name: core_type
  label: 核类型
  type: string
- name: early_avg_freq_mhz
  label: 初期均频(MHz)
  type: number
- name: steady_avg_freq_mhz
  label: 稳态均频(MHz)
  type: number
- name: max_freq_mhz
  label: 最高频率(MHz)
  type: number
- name: rampup_pct
  label: 爬升幅度(%)
  type: percentage
  format: percentage
- name: assessment
  label: 评估
  type: string
```
