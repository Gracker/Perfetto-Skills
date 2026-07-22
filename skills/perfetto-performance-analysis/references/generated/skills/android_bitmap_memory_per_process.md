GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_bitmap_memory_per_process.skill.yaml
Source SHA-256: 3c84f44d6c902b27eaae06e9700024c9d6954005525a587cdbf9f2863e52423b
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# Bitmap 内存（按进程）

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_bitmap_memory_per_process
version: '1.1'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Bitmap 内存（按进程）
description: 每进程 Bitmap counter、heap graph metadata 和跨进程来源归因
icon: image
tags:
- memory
- bitmap
- image
- heap_graph
- atomic
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
  description: 目标进程名（可选，前缀匹配）
- name: package
  type: string
  required: false
  description: 目标包名（可选，前缀匹配）
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
    label: Bitmap 数量
    type: number
    format: compact
  - name: total_bytes
    label: 总字节
    type: bytes
    format: compact
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
```
