GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/pipeline_4feature_scoring.skill.yaml
Source SHA-256: 2188f6c3732115b4eac2d4d5250a23f8ff912ecab084d6aabc732df5c69ccef3
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# Pipeline 4 轴辅助证据评分

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_4feature_scoring
version: '1.0'
type: composite
category: rendering
tier: B
```

## Metadata

```yaml
display_name: Pipeline 4 轴辅助证据评分
description: 归一化 Producer/Layer/BufferQueue/节奏证据；不能脱离 S02-S14 最小证据集单独定型
icon: category
tags:
- pipeline
- classification
- four-features
- s01
s_article_ref: S01
```

## Triggers

```yaml
keywords:
  zh:
  - 渲染管线评分
  - 四特征
  - 管线分类
  - pipeline scoring
  - queueBuffer
  en:
  - pipeline scoring
  - rendering pipeline classification
  - four features
  - queueBuffer
patterns:
- .*(渲染管线|pipeline).*(评分|分类|识别).*
- .*(pipeline|rendering).*(score|classification).*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_track
- thread
- process
modules:
- slices.with_context
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选）
```

## Ordered execution

### Producer 线程数（特征 1）

- ID: `producer_thread_signature`
- Type: `atomic`
- SQL: [`../sql/pipeline_4feature_scoring/producer_thread_signature.sql`](../sql/pipeline_4feature_scoring/producer_thread_signature.sql)

```yaml
id: producer_thread_signature
type: atomic
display:
  level: summary
  layer: overview
  title: Producer 线程签名
  columns:
  - name: producer_thread_count
    label: Producer 线程数
    type: number
  - name: producer_thread_names
    label: Producer 线程名样本
    type: string
  - name: signature_type
    label: Producer 签名类型
    type: string
save_as: producer_thread_signature
```
### Layer 数（特征 2）

- ID: `layer_signature`
- Type: `atomic`
- SQL: [`../sql/pipeline_4feature_scoring/layer_signature.sql`](../sql/pipeline_4feature_scoring/layer_signature.sql)

```yaml
id: layer_signature
type: atomic
display:
  level: summary
  layer: overview
  title: SF 侧 Layer 签名
  columns:
  - name: app_layer_count
    label: App layer 数
    type: number
  - name: layer_signature_type
    label: Layer 签名类型
    type: string
save_as: layer_signature
```
### BufferQueue 路径（特征 3）

- ID: `bufferqueue_path`
- Type: `atomic`
- SQL: [`../sql/pipeline_4feature_scoring/bufferqueue_path.sql`](../sql/pipeline_4feature_scoring/bufferqueue_path.sql)

```yaml
id: bufferqueue_path
type: atomic
display:
  level: summary
  layer: overview
  title: BufferQueue 路径签名
  columns:
  - name: bq_path_type
    label: BufferQueue 路径类型
    type: string
  - name: blast_count
    label: BLAST slice 数
    type: number
  - name: legacy_count
    label: Legacy queueBuffer 数
    type: number
  - name: software_count
    label: Software lockCanvas 数
    type: number
  - name: ndk_sc_count
    label: NDK ASurfaceTransaction 数
    type: number
save_as: bufferqueue_path
```
### 额外节奏源（特征 4）

- ID: `extra_rhythm`
- Type: `atomic`
- SQL: [`../sql/pipeline_4feature_scoring/extra_rhythm.sql`](../sql/pipeline_4feature_scoring/extra_rhythm.sql)

```yaml
id: extra_rhythm
type: atomic
display:
  level: summary
  layer: overview
  title: 额外节奏源签名
  columns:
  - name: rhythm_source
    label: 主导节奏源
    type: string
  - name: vsync_app_only
    label: 仅 vsync-app
    type: string
save_as: extra_rhythm
```
## Output and evidence contract

```yaml
fields:
- name: producer_thread_signature
  label: '特征 1: Producer 线程签名'
- name: layer_signature
  label: '特征 2: Layer 签名'
- name: bufferqueue_path
  label: '特征 3: BufferQueue 路径'
- name: extra_rhythm
  label: '特征 4: 额外节奏源'
```
