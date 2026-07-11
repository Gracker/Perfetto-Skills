GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/surface_control_api.skill.yaml
Source SHA-256: 2eb2e71b27a7efad70155707e0e860287258d2c677fc3f1c388aead8b6dac750
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# SurfaceControl API

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_surface_control_api
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: SURFACE_CONTROL_API
display_name: SurfaceControl API
description: NDK SurfaceControl 直接事务提交，低级别表面控制
icon: code
family: surface
doc_path: rendering_pipelines/surface_control_api.md
s_article_ref: S03
four_features:
  producer_threads:
  - main
  - any custom thread (NDK ANativeWindow_*)
  expected_layer_count: 1+
  bufferqueue_path: ANATIVEWINDOW + ASURFACETRANSACTION
  extra_rhythm_sources: []
deviation_anchors: ndk_direct_anchor_4_5_6_no_view_root
shared_with_blast_note: 'SurfaceControl API 与 BLAST 共享同一事务式更新体系，但不等价：

  - BLAST (BLASTBufferQueue) 内部用 SurfaceControl Transaction 实现 buffer + 几何原子性

  - SurfaceControl API 是直接暴露给 NDK 的接口

  BLAST 是上层抽象，SurfaceControl API 是底层接口。trace 上看到 ASurfaceTransaction* 是 NDK 直接使用，

  看到 BLASTBufferQueue* 是 HWUI 通过 BLAST 使用——同体系但不同层次。

  '
```

## Detection

```yaml
required_signals:
- slice_pattern: '*ASurfaceTransaction*'
  min_count: 1
scoring_signals:
- signal: has_asurface_control
  slice_pattern: '*ASurfaceControl*'
  min_count: 5
  weight: 30
- signal: has_asurface_transaction
  slice_pattern: '*ASurfaceTransaction*'
  min_count: 5
  weight: 35
- signal: has_apply_transaction
  slice_pattern: '*ASurfaceTransaction_apply*'
  weight: 20
- signal: has_native_window
  slice_pattern: '*ANativeWindow*'
  weight: 15
```

## Teaching model

```yaml
title: SurfaceControl API 渲染管线
summary: '使用 NDK SurfaceControl API 直接控制 Surface 和 Transaction。

  提供最低级别的合成控制，可以创建子 Surface、控制 Z-order、

  原子性更新多个属性。它与 BLAST 共享同一事务式更新体系，

  但不应被简单理解为“SurfaceControl API 就等于 BLAST”。

  '
mermaid: "sequenceDiagram\n  participant App as App (NDK)\n  participant SC as SurfaceControl\n  participant TX as Transaction\n\
  \  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over App,SF:\
  \ \U0001F4CD NDK SurfaceControl API\n  App->>SC: ASurfaceControl_create\n  App->>BQ: ANativeWindow_dequeueBuffer\n  App->>App:\
  \ GPU 渲染\n  App->>BQ: ANativeWindow_queueBuffer\n\n  App->>TX: ASurfaceTransaction_create\n  App->>TX: 设置 Buffer/几何/混合模式\n\
  \  App->>TX: ASurfaceTransaction_apply\n\n  TX-->>SF: Transaction 提交\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF:\
  \ 接收并处理 Transaction\n  SF->>SF: latchBuffer\n  SF->>SF: HWC 合成\n  deactivate SF\n\n  Note over App,SF: \U0001F527 低级别 API，完全控制\
  \ Buffer 和 Surface\n"
thread_roles:
- thread: main
  role: SurfaceControl 控制
  description: 创建 Surface、构建和提交 Transaction
- thread: any
  role: 生产者线程
  description: 在任意线程渲染/写入 Buffer，并与 Transaction 提交节拍对齐
- thread: SurfaceFlinger
  role: 事务处理/合成
  description: 接收 Transaction、latch Buffer、合成并提交到 HWC
key_slices:
- name: ASurfaceControl
  thread: any
  description: NDK SurfaceControl 操作（create/destroy/reparent 等）
- name: ASurfaceTransaction_apply
  thread: any
  description: 提交 Transaction（原子性更新多个属性）
- name: setTransactionState
  thread: SurfaceFlinger
  description: SurfaceFlinger 处理 Transaction 的常见提示信号；名称依版本和 tracing 变化
```

## Analysis guidance

```yaml
common_issues:
- id: transaction_batching
  name: Transaction 批量提交不当
  description: 频繁的小 Transaction 提交导致 SurfaceFlinger 负载
  detection_skill: sf_frame_consumption
- id: buffer_fence_wait
  name: Buffer Fence 等待过长
  description: GPU 渲染未完成时提交 Transaction，导致 SF 等待
  detection_skill: present_fence_timing
- id: layer_hierarchy_deep
  name: Layer 层级过深
  description: 过多 Child Layer 导致合成开销
  detection_skill: surfaceflinger_analysis
- id: transaction_merge_for_atomicity
  name: Transaction 未合并导致几何与 buffer 不同帧
  description: 'NDK 应用应该把多个 ASurfaceTransaction_set* 操作合到同一个 transaction 再 apply，

    而不是分别 apply。多个独立 transaction 不保证在同一帧生效，会出现几何与 buffer 错位一帧。

    S05 §"系统提供的多 Surface 同步机制"。

    '
  detection_skill: sf_composition_in_range
- id: ndk_acquire_fence_propagation
  name: NDK Producer 必须正确传递 acquire fence
  description: 'NDK Producer 调用 ASurfaceTransaction_setBuffer 时必须正确传 acquire fence

    （ANativeWindow_lockBuffer/queueBuffer 的 fence FD），否则 SF 可能读到 GPU 未写完的 buffer。

    '
  detection_skill: present_fence_timing
- id: async_apply_no_completion_callback
  name: ASurfaceTransaction_apply 默认异步无完成回调
  description: 'ASurfaceTransaction_apply 默认是异步——返回不代表 transaction 已生效。

    需要等待生效用 ASurfaceTransaction_setOnComplete 或 ASurfaceTransaction_setOnCommit 注册回调。

    Android 13+ TransactionCommittedListener 是公开 API。

    '
  detection_skill: render_thread_slices
recommended_skills:
- sf_frame_consumption
- binder_analysis
- present_fence_timing
- surfaceflinger_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: SurfaceControl 控制 (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程（避免 pin 到系统/其他 app 的 main）
- pattern: Transaction
  match_by: name
  priority: 3
  reason: 事务提交 (传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程相关的 Transaction 轨道
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 5.5
  reason: VSync (SurfaceFlinger 消费/合成)
- pattern: ^BufferTX
  match_by: name
  priority: 6
  reason: BufferTX (SurfaceFlinger 事务)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 7
  reason: Transaction 处理/显示
  main_thread_only: true
```
