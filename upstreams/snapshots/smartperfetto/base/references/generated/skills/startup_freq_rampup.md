GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_freq_rampup.skill.yaml
Source SHA-256: 6f5c949fb38180d0c6f2fb90172a4357d8a192a449da1c88d7bfe8ebade4a876
Source commit: bc007586871a720aed82537913617c64fb95a459
# 启动 CPU 频率爬升

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_freq_rampup
version: '1.1'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动 CPU 频率爬升
description: 比较启动初期与后段的逐核频率及覆盖率，不据此判定升频延迟
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
title: CPU 频率阶段对比
columns:
- name: ucpu
  label: UCPU
  type: number
- name: cpu
  label: CPU
  type: number
- name: machine_id
  label: Machine ID
  type: number
- name: early_avg_freq_mhz
  label: 初期均频(MHz)
  type: number
- name: steady_avg_freq_mhz
  label: 后段均频(MHz)
  type: number
- name: max_freq_mhz
  label: 观测峰值(MHz)
  type: number
- name: early_covered_ns
  label: 初期覆盖时长
  type: duration
  unit: ns
- name: early_window_ns
  label: 初期窗口时长
  type: duration
  unit: ns
- name: steady_covered_ns
  label: 后段覆盖时长
  type: duration
  unit: ns
- name: steady_window_ns
  label: 后段窗口时长
  type: duration
  unit: ns
- name: rampup_pct
  label: 后段相对变化(%)
  type: percentage
  format: percentage
- name: assessment
  label: 评估
  type: string
- name: claim_boundary
  label: 证据边界
  type: string
```
