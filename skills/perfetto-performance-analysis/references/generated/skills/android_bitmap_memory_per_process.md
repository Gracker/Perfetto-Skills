GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
Source SHA-256: 0b50760adf1ce6444677ccef1d5b8511489b81f17a4007ec9e3efff6c919964b
# Bitmap 内存（按进程）

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_bitmap_memory_per_process
version: '1.3'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Bitmap 内存（按进程）
description: 每进程 Bitmap counter 峰值与存活集增长形状、heap graph metadata 和跨进程来源归因
icon: image
tags:
- memory
- bitmap
- image
- heap_graph
- leak
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - Bitmap
  - 位图
  - 图片内存
  - Bitmap 泄漏
  en:
  - bitmap
  - bitmap memory
  - bitmap leak
```

## Prerequisites

```yaml
modules:
- android.bitmaps
- android.memory.heap_graph.bitmap
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名（精确或 name:* 子进程，见 fragments/heap_target_process.sql）；为空则统计全部进程；无匹配时回退到没有进程名的 dump（如 .hprof）
- name: package
  type: string
  required: false
  description: 目标包名（精确或 name:* 子进程）；process_name 为空时使用
- name: upid
  type: integer
  required: false
  description: 可选的稳定进程身份；进程名不可用时（.hprof）用它限定进程
- name: start_ts
  type: timestamp
  required: false
  description: bitmap_live_shape 的分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: bitmap_live_shape 的分析结束时间戳(ns)
- name: bitmap_growth_min_mb
  type: number
  required: false
  default: 32
  description: Bitmap 存活集净增长低于该值(MB)时只报 below_growth_threshold，不做形状判别，默认 32
```

## Ordered execution

### Bitmap 内存按进程

- ID: `bitmap_memory`
- Type: `atomic`
- SQL: [`../sql/android_bitmap_memory_per_process/bitmap_memory.sql`](../sql/android_bitmap_memory_per_process/bitmap_memory.sql)

```yaml
id: bitmap_memory
type: atomic
display:
  level: detail
  layer: list
  title: Bitmap 内存占用
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: bitmap_count
    label: 峰值时 Bitmap 数量
    type: number
    format: compact
  - name: total_bytes
    label: Bitmap 内存峰值
    type: bytes
    format: compact
  - name: peak_ts
    label: 峰值时刻
    type: timestamp
  - name: process_identity
    label: 进程身份
    type: string
sql_fragments:
- fragments/heap_target_process.sql
```
### Bitmap 存活集形状

- ID: `bitmap_live_shape`
- Type: `atomic`
- SQL: [`../sql/android_bitmap_memory_per_process/bitmap_live_shape.sql`](../sql/android_bitmap_memory_per_process/bitmap_live_shape.sql)

```yaml
id: bitmap_live_shape
type: atomic
display:
  level: summary
  layer: overview
  title: Bitmap 存活集增长形状
  title_i18n:
    en: Bitmap Live-Set Growth Shape
  row_semantics: per_entity
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: samples
    label: 样本数
    type: number
    format: compact
  - name: span_s
    label: 覆盖时长(s)
    type: number
  - name: first_mb
    label: 初始 Bitmap 内存(MB)
    type: number
  - name: last_mb
    label: 结束 Bitmap 内存(MB)
    type: number
  - name: net_growth_mb
    label: 净增长(MB)
    type: number
  - name: rise_steps
    label: 上升步数
    type: number
    format: compact
  - name: drop_steps
    label: 回落步数
    type: number
    format: compact
    semantics: Count of samples where Bitmap Memory decreased. Bitmap Memory is a live-set counter that drops when a bitmap
      is freed, so zero drops across GCs means nothing was released in the span.
  - name: max_single_drop_mb
    label: 最大单次回落(MB)
    type: number
  - name: first_count
    label: 初始 Bitmap 数
    type: number
    format: compact
  - name: last_count
    label: 结束 Bitmap 数
    type: number
    format: compact
  - name: gcs_in_span
    label: 期间 GC 次数
    type: number
    format: compact
    semantics: ART collector runs (slices named like "* concurrent copying GC") of this process between the first and last
      Bitmap sample.
  - name: shape
    label: 形状
    label_i18n:
      en: Shape
    type: string
    semantics: 'retained_growth_across_gc: grew past threshold, never dropped, GC ran in span, so the live set only grew.
      RSS omits untouched pixel pages; flat RSS does not contradict it.'
  - name: process_identity
    label: 进程身份
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/art_gc_names.sql
save_as: bitmap_live_shape
```
### Heap Graph Bitmap 数据可用性

- ID: `heap_bitmap_availability`
- Type: `atomic`
- SQL: [`../sql/android_bitmap_memory_per_process/heap_bitmap_availability.sql`](../sql/android_bitmap_memory_per_process/heap_bitmap_availability.sql)

```yaml
id: heap_bitmap_availability
type: atomic
display: false
save_as: heap_bitmap_availability
```
### Heap Graph Bitmap 元数据

- ID: `heap_bitmap_metadata`
- Type: `atomic`
- SQL: [`../sql/android_bitmap_memory_per_process/heap_bitmap_metadata.sql`](../sql/android_bitmap_memory_per_process/heap_bitmap_metadata.sql)

```yaml
id: heap_bitmap_metadata
type: atomic
optional: true
condition: heap_bitmap_availability.data[0]?.has_heap_graph_bitmaps == 1
display:
  level: detail
  layer: list
  title: Heap Graph Bitmap 元数据
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: bitmap_object_count
    label: Bitmap 对象
    type: number
    format: compact
  - name: reachable_count
    label: 可达对象
    type: number
    format: compact
  - name: total_bytes
    label: 总字节
    type: bytes
    format: bytes_human
  - name: native_bytes
    label: Native 字节
    type: bytes
    format: bytes_human
  - name: java_self_bytes
    label: Java 对象字节
    type: bytes
    format: bytes_human
  - name: known_dimension_count
    label: 有尺寸对象
    type: number
    format: compact
  - name: max_width
    label: 最大宽度
    type: number
    format: compact
  - name: max_height
    label: 最大高度
    type: number
    format: compact
  - name: storage_types
    label: 存储类型
    type: string
  - name: process_identity
    label: 进程身份
    type: string
sql_fragments:
- fragments/heap_target_process.sql
```
### 跨进程 Bitmap 来源归因

- ID: `heap_bitmap_sender_attribution`
- Type: `atomic`
- SQL: [`../sql/android_bitmap_memory_per_process/heap_bitmap_sender_attribution.sql`](../sql/android_bitmap_memory_per_process/heap_bitmap_sender_attribution.sql)

```yaml
id: heap_bitmap_sender_attribution
type: atomic
optional: true
condition: heap_bitmap_availability.data[0]?.has_heap_graph_bitmaps == 1
display:
  level: detail
  layer: list
  title: 跨进程 Bitmap 来源
  columns:
  - name: receiver_process
    label: 接收进程
    type: string
  - name: source_process
    label: 来源进程
    type: string
  - name: bitmap_count
    label: Bitmap 数量
    type: number
    format: compact
  - name: total_bytes
    label: 总字节
    type: bytes
    format: bytes_human
  - name: receiver_storage_types
    label: 接收端存储
    type: string
  - name: source_storage_types
    label: 来源端存储
    type: string
  - name: process_identity
    label: 接收进程身份
    type: string
sql_fragments:
- fragments/heap_target_process.sql
```
