GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/lock_binder_wait.skill.yaml
Source SHA-256: 6f37cd847c361b12b95f9490498ee8a48e810631a2f8f708934ee961343ed9d5
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 锁/Binder 等待分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: lock_binder_wait
version: '1.0'
type: composite
category: diagnostics
tier: B
```

## Metadata

```yaml
display_name: 锁/Binder 等待分析
description: 下钻 reason_code=lock_binder_wait 的帧窗口，检查主线程睡眠、唤醒链、锁竞争和同步 Binder 阻塞
icon: link
tags:
- lock
- binder
- blocking
- wait
- jank
- root_cause
```

## Triggers

```yaml
keywords:
  zh:
  - 锁等待
  - Binder 等待
  - lock_binder_wait
  - 主线程等待
  - 唤醒链
  en:
  - lock wait
  - binder wait
  - lock_binder_wait
  - main thread wait
  - waker chain
patterns:
- .*lock_binder_wait.*
- .*(锁|Binder).*(等待|阻塞).*
- .*(lock|binder).*(wait|blocking).*
```

## Prerequisites

```yaml
required_tables:
- thread_state
- thread
- process
modules:
- android.binder
- android.monitor_contention
- slices.with_context
```

## Inputs

```yaml
- name: process_name
  type: string
  required: true
  description: 目标进程名
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
```

## Identity requirements

```yaml
policy: required
scope: process
aliases:
- process_name
- package
rewriteTo: recommended_process_name_param
```

## Ordered execution

### 主线程阻塞链

- ID: `main_thread_blocking_chain`
- Type: `skill`

```yaml
id: main_thread_blocking_chain
type: skill
skill: blocking_chain_analysis
params:
  process_name: ${process_name}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: blocking_chain
optional: true
```
### 锁竞争明细

- ID: `monitor_lock_contention`
- Type: `skill`

```yaml
id: monitor_lock_contention
type: skill
skill: lock_contention_in_range
params:
  package: ${process_name}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: lock_contention
optional: true
```
### 同步 Binder 阻塞

- ID: `sync_binder_blocking`
- Type: `skill`

```yaml
id: sync_binder_blocking
type: skill
skill: binder_blocking_in_range
params:
  package: ${process_name}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: binder_blocking
optional: true
```
## Synthesis

```yaml
template: 'lock_binder_wait 深钻已完成：

  - blocking_chain: ${blocking_chain.summary}

  - lock_contention: ${lock_contention.summary}

  - binder_blocking: ${binder_blocking.summary}

  '
```
