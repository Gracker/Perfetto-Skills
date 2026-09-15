GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/thread_preemption_handoffs_in_range.skill.yaml
Source SHA-256: 0d6aa446f7bc33de7c1867ce6be9c1042f9c3ba2c3da5fa80100744c268332ef
Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5
# 实际抢占交接与目标等待

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thread_preemption_handoffs_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 实际抢占交接与目标等待
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
- name: package
  type: string
  required: false
- name: utid
  type: number
  required: false
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Query

Run [`../sql/thread_preemption_handoffs_in_range/query.sql`](../sql/thread_preemption_handoffs_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 实际抢占交接与目标等待
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
- name: upid
  label: upid
  type: number
- name: pid
  label: pid
  type: number
- name: process_name
  label: process_name
  type: string
- name: utid
  label: utid
  type: number
- name: tid
  label: tid
  type: number
- name: thread_name
  label: thread_name
  type: string
- name: role
  label: role
  type: string
- name: sched_id
  label: sched_id
  type: number
  hidden: true
- name: ucpu
  label: ucpu
  type: number
- name: cpu
  label: cpu
  type: number
- name: raw_start_ts
  label: raw_start_ts
  type: timestamp
  unit: ns
  hidden: true
- name: raw_dur
  label: raw_dur
  type: duration
  unit: ns
  hidden: true
- name: raw_end_ts
  label: raw_end_ts
  type: timestamp
  unit: ns
  hidden: true
- name: switch_ts
  label: switch_ts
  type: timestamp
  unit: ns
- name: priority
  label: priority
  type: number
- name: end_state
  label: end_state
  type: string
- name: peer_sched_id
  label: peer_sched_id
  type: number
  hidden: true
- name: peer_utid
  label: peer_utid
  type: number
- name: peer_is_idle
  label: peer_is_idle
  type: number
- name: peer_role
  label: peer_role
  type: string
- name: peer_upid
  label: peer_upid
  type: number
- name: peer_tid
  label: peer_tid
  type: number
- name: peer_thread_name
  label: peer_thread_name
  type: string
- name: peer_process_name
  label: peer_process_name
  type: string
- name: peer_start_ts
  label: peer_start_ts
  type: timestamp
  unit: ns
- name: peer_raw_dur
  label: peer_raw_dur
  type: number
- name: peer_priority
  label: peer_priority
  type: number
- name: peer_end_state
  label: peer_end_state
  type: string
- name: runnable_state_id
  label: runnable_state_id
  type: number
  hidden: true
- name: runnable_start_ts
  label: runnable_start_ts
  type: timestamp
  unit: ns
- name: runnable_raw_dur
  label: runnable_raw_dur
  type: number
- name: runnable_end_ts
  label: runnable_end_ts
  type: timestamp
  unit: ns
- name: runnable_overlap_ns
  label: runnable_overlap_ns
  type: duration
  unit: ns
- name: runnable_right_censored
  label: runnable_right_censored
  type: number
- name: handoff_evidence
  label: handoff_evidence
  type: string
- name: scheduling_policy_evidence
  label: scheduling_policy_evidence
  type: string
- name: evidence_scope
  label: evidence_scope
  type: string
```
