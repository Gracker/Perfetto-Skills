GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_system_context_in_range.skill.yaml
Source SHA-256: 3710a589131ec1ee6dd86475a1c8d00a5b2cc57ed4a1ccead52b2dbaeb4b050d
Source commit: bc007586871a720aed82537913617c64fb95a459
# 逐核系统供给与覆盖

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_system_context_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 逐核系统供给与覆盖
description: 范围内可定位的系统观测，保留覆盖与缺失；不单凭相关性判断根因
icon: analytics
tags:
- system
- scheduling
- evidence
- range
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

Run [`../sql/cpu_system_context_in_range/query.sql`](../sql/cpu_system_context_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 逐核系统供给与覆盖
columns:
- name: window_id
  label: window_id
  type: number
  hidden: true
- name: window_start_ts
  label: window_start_ts
  type: timestamp
  unit: ns
  hidden: true
- name: window_end_ts
  label: window_end_ts
  type: timestamp
  unit: ns
  hidden: true
- name: window_dur_ns
  label: window_dur_ns
  type: duration
  unit: ns
  hidden: true
- name: ucpu
  label: ucpu
  type: number
- name: cpu
  label: cpu
  type: number
- name: machine_id
  label: machine_id
  type: number
  hidden: true
- name: cluster_id
  label: cluster_id
  type: number
  hidden: true
- name: capacity
  label: capacity
  type: number
- name: core_type
  label: core_type
  type: string
- name: topology_source
  label: topology_source
  type: string
- name: avg_freq_khz
  label: avg_freq_khz
  type: number
- name: min_freq_khz
  label: min_freq_khz
  type: number
- name: observed_max_freq_khz
  label: observed_max_freq_khz
  type: number
- name: frequency_covered_ns
  label: frequency_covered_ns
  type: duration
  unit: ns
- name: frequency_evidence
  label: frequency_evidence
  type: string
- name: frequency_source
  label: frequency_source
  type: string
- name: sched_covered_ns
  label: sched_covered_ns
  type: duration
  unit: ns
- name: busy_ns
  label: busy_ns
  type: duration
  unit: ns
- name: idle_ns
  label: idle_ns
  type: duration
  unit: ns
- name: idle_identity_unknown_ns
  label: idle_identity_unknown_ns
  type: duration
  unit: ns
- name: busy_pct
  label: busy_pct
  type: percentage
- name: unfinished_sched_ns
  label: unfinished_sched_ns
  type: duration
  unit: ns
- name: sched_evidence
  label: sched_evidence
  type: string
- name: evidence_scope
  label: evidence_scope
  type: string
```
