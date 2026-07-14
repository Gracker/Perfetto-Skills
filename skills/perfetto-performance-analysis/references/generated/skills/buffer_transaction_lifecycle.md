GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
Source SHA-256: 9bd45c1ab88d6a908b1cc3212e0851489d75932736c4544a9bec8983237545b2
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Buffer Transaction 生命周期

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: buffer_transaction_lifecycle
version: '1.0'
type: composite
category: diagnostics
tier: B
```

## Metadata

```yaml
display_name: Buffer Transaction 生命周期
description: 追踪 BLAST Transaction 在 SF 侧的真实计数点（S01 §⑥），区分 queueBuffer 与 Transaction 到达时机
icon: swap_horiz
tags:
- surfaceflinger
- transaction
- blast
- buffer
- lifecycle
- s01
s_article_ref: S01
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 应用包名（可选，用于过滤目标 layer）
```

## Ordered execution

### SF applyTransaction 概览

- ID: `apply_transaction_summary`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/apply_transaction_summary.sql`](../sql/buffer_transaction_lifecycle/apply_transaction_summary.sql)

```yaml
id: apply_transaction_summary
type: atomic
display:
  level: summary
  layer: overview
  title: SF Transaction 真实计数点
  columns:
  - name: total_apply_transactions
    label: applyTransaction 总次数
    type: number
  - name: total_set_transaction_state
    label: setTransactionState 总次数
    type: number
  - name: total_blast_bq
    label: BLASTBufferQueue slice 总次数
    type: number
  - name: total_queue_buffer
    label: queueBuffer 总次数
    type: number
  - name: avg_apply_to_latch_ms
    label: 平均 Transaction→Latch 间隔
    type: duration
    format: duration_ms
save_as: apply_transaction_summary
```
### queueBuffer → Transaction 到达延迟

- ID: `queue_to_transaction_delay`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/queue_to_transaction_delay.sql`](../sql/buffer_transaction_lifecycle/queue_to_transaction_delay.sql)

```yaml
id: queue_to_transaction_delay
type: atomic
display:
  level: detail
  layer: list
  title: App queueBuffer 到 SF Transaction 真实到达的延迟
  columns:
  - name: bucket
    label: 延迟区间
    type: string
  - name: count
    label: 次数
    type: number
save_as: queue_to_transaction_delay
```
### 按 Layer 分组的 Transaction 计数

- ID: `per_layer_transactions`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/per_layer_transactions.sql`](../sql/buffer_transaction_lifecycle/per_layer_transactions.sql)

```yaml
id: per_layer_transactions
type: atomic
display:
  level: detail
  layer: list
  title: Per-layer Transaction 分布
  columns:
  - name: layer_name
    label: Layer 名
    type: string
  - name: frame_count
    label: 帧数
    type: number
  - name: jank_count
    label: Jank 数
    type: number
  - name: avg_dur_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
save_as: per_layer_transactions
```
## Output and evidence contract

```yaml
fields:
- name: apply_transaction_summary
  label: Transaction 概览（S01 §⑥ 真实计数点）
- name: queue_to_transaction_delay
  label: queueBuffer → Transaction 延迟分布
- name: per_layer_transactions
  label: Per-layer Transaction 分布
```
