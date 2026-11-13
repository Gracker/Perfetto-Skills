GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/buffer_transaction_lifecycle.skill.yaml
Source SHA-256: 977f9ee7b1e356090321193837d29dbd067b40b9ba43929e9c297508292d5421
# Buffer Transaction 生命周期

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: buffer_transaction_lifecycle
version: '1.1'
type: composite
category: diagnostics
tier: B
```

## Metadata

```yaml
display_name: Buffer Transaction 生命周期
description: 观察 SF 全局事务事件、目标进程提交事件与逐轨 BufferTX pending；缺少 buffer/layer/transaction 身份时不计算跨阶段延迟
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
- thread_track
- thread
- process
- counter
- counter_track
- actual_frame_timeline_slice
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
  description: 精确包名及冒号子进程；BufferTX 按 layer 名边界匹配，空值观察全部进程
```

## Ordered execution

### 事务与提交事件概览

- ID: `apply_transaction_summary`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/apply_transaction_summary.sql`](../sql/buffer_transaction_lifecycle/apply_transaction_summary.sql)

```yaml
id: apply_transaction_summary
type: atomic
display:
  level: summary
  layer: overview
  title: SF 全局事件与目标进程提交事件（未关联单个 buffer）
  columns:
  - name: total_apply_transactions
    label: SF 全局 applyTransaction 事件数
    type: number
  - name: total_set_transaction_state
    label: SF 全局 setTransactionState 事件数
    type: number
  - name: total_blast_bq
    label: 所选进程 BLASTBufferQueue 事件数
    type: number
  - name: total_queue_buffer
    label: 所选进程 queueBuffer 事件数（非显示帧数）
    type: number
  - name: avg_apply_to_latch_ms
    label: Transaction→Latch 延迟（缺身份关联，不可用）
    type: duration
    format: duration_ms
  - name: pairing_status
    label: 跨阶段关联状态
    type: string
  - name: sf_event_scope
    label: SF 事件范围
    type: string
  - name: app_event_scope
    label: 应用事件范围
    type: string
save_as: apply_transaction_summary
```
### queueBuffer→Transaction 关联能力

- ID: `queue_to_transaction_delay`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/queue_to_transaction_delay.sql`](../sql/buffer_transaction_lifecycle/queue_to_transaction_delay.sql)

```yaml
id: queue_to_transaction_delay
type: atomic
display:
  level: detail
  layer: list
  title: 缺少 buffer/layer/transaction 身份，跨阶段延迟不可用
  columns:
  - name: bucket
    label: 延迟统计可用性
    type: string
  - name: count
    label: 已关联样本数（不可用）
    type: number
  - name: pairing_status
    label: 跨阶段关联状态
    type: string
save_as: queue_to_transaction_delay
```
### 按进程与 Layer 分组的 FrameTimeline 记录

- ID: `per_layer_transactions`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/per_layer_transactions.sql`](../sql/buffer_transaction_lifecycle/per_layer_transactions.sql)

```yaml
id: per_layer_transactions
type: atomic
display:
  level: detail
  layer: list
  title: 完整 FrameTimeline 记录（非 Transaction 或新 buffer 计数）
  columns:
  - name: upid
    label: 进程实例 UPID
    type: number
  - name: process_name
    label: 进程名
    type: string
  - name: layer_name
    label: Layer 名
    type: string
  - name: frame_count
    label: 完整 FrameTimeline 记录数（非去重 App 帧）
    type: number
  - name: jank_count
    label: 带 Jank 标记的记录数
    type: number
  - name: avg_dur_ms
    label: 记录平均时长
    type: duration
    format: duration_ms
  - name: evidence_scope
    label: 证据口径
    type: string
save_as: per_layer_transactions
```
### 逐轨 BufferTX pending 观测

- ID: `buffer_tx_pending_observations`
- Type: `atomic`
- SQL: [`../sql/buffer_transaction_lifecycle/buffer_tx_pending_observations.sql`](../sql/buffer_transaction_lifecycle/buffer_tx_pending_observations.sql)

```yaml
id: buffer_tx_pending_observations
type: atomic
display:
  level: detail
  layer: list
  title: SF server pending 增减与水位（不等于 GPU ready 或显示帧）
  columns:
  - name: track_id
    label: Counter 轨道 ID
    type: number
  - name: track_name
    label: BufferTX 轨道名
    type: string
  - name: sample_count
    label: 窗口内样本数
    type: number
  - name: received_updates
    label: Pending 上升量（收到 buffer update）
    type: number
  - name: removed_updates
    label: Pending 下降量（latch 或 drop）
    type: number
  - name: min_pending_updates
    label: 采样最低 pending 水位
    type: number
  - name: max_pending_updates
    label: 采样最高 pending 水位
    type: number
  - name: last_pending_updates
    label: 窗口末次采样 pending 水位
    type: number
  - name: coverage_status
    label: 增量观测覆盖
    type: string
  - name: evidence_scope
    label: 归属口径
    type: string
  - name: claim_boundary
    label: 结论边界
    type: string
save_as: buffer_tx_pending_observations
```
## Output and evidence contract

```yaml
fields:
- name: apply_transaction_summary
  label: SF 全局事件与所选进程提交事件
- name: queue_to_transaction_delay
  label: queueBuffer→Transaction 关联能力（缺身份时不可用）
- name: per_layer_transactions
  label: Per-layer FrameTimeline 记录（空结果不证明流畅）
- name: buffer_tx_pending_observations
  label: 逐轨 BufferTX pending 增减与水位
```
