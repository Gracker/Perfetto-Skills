GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/rn_new_arch.skill.yaml
Source SHA-256: b94227421d2d776d786f3557a60355a324b6f405cc9f4b06b57febab8b5af224
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# React Native New Arch (Fabric + JSI)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_rn_new_arch
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: RN_NEW_ARCH_HWUI
display_name: React Native New Arch (Fabric + JSI)
description: RN 新架构：JSI 直接 C++ 调用 + Fabric C++ Shadow tree + TurboModules + 宿主 HWUI
icon: react
family: webview
doc_path: rendering_pipelines/rn_new_arch.md
s_article_ref: S14
four_features:
  producer_threads:
  - mqt_js
  optional_producer_threads:
  - Fabric background thread
  consumer_threads:
  - main
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: JS_TO_JSI_TO_FABRIC_TO_HOST_HWUI
  extra_rhythm_sources:
  - jsi_synchronous_call
deviation_anchors: rn_jsi_anchor_2_3_at_js_layer_lower_latency_than_old_arch
fabric_advantages: '相比 Old Arch 的优势（来自 S14）：

  - JSI 同步调用：JS ↔ Native 直接 C++ 通信，无 JSON 序列化

  - Fabric C++ Shadow tree：layout 计算从 mqt_shadow_queue 移到 Fabric background thread

  - Fabric mount 原子：所有 View 更新在同一帧 commit

  - UI 更新延迟比 Old Arch 低（典型从 1-2 帧降到 0-1 帧）

  '
```

## Detection

```yaml
required_signals:
- slice_pattern: '*FabricUIManager*'
  min_count: 1
scoring_signals:
- signal: has_fabric_uimanager
  slice_pattern: '*FabricUIManager*'
  weight: 50
- signal: has_fabric_commit
  slice_pattern: '*FabricCommit*'
  weight: 25
- signal: has_fabric_mount
  slice_pattern: '*FabricMount*'
  weight: 25
- signal: has_jsi_call
  slice_pattern: '*JSI*'
  weight: 15
- signal: has_turbomodule
  slice_pattern: '*TurboModule*'
  weight: 15
- signal: has_mqt_js
  thread_pattern: mqt_js*
  weight: 20
exclude_if:
- thread_pattern: mqt_shadow*
```

## Teaching model

```yaml
title: React Native New Arch (Fabric + JSI) 渲染管线
summary: 'RN 新架构基于 Fabric 渲染器 + JSI：

  - JS 线程（mqt_js）执行 React 业务逻辑

  - JSI 直接 C++ 调用（无 JSON 序列化）

  - Fabric C++ Shadow tree（不再有 mqt_shadow_queue）

  - Fabric commit + mount 原子化 View 创建/更新

  - 最终走宿主 HWUI RenderThread

  '
key_slices:
- name: FabricUIManager
  thread: any
  description: Fabric UI manager 入口
- name: FabricCommit / FabricMount
  thread: any
  description: Fabric 原子提交 View 更新
- name: JSI
  thread: any
  description: JSI 直接 C++ 调用（无 JSON）
- name: TurboModule
  thread: any
  description: TurboModule 同步调用 native 模块
```

## Analysis guidance

```yaml
common_issues:
- id: js_thread_blocking
  name: JS 线程阻塞
  description: JS 业务逻辑慢、Hermes GC pause——与 Old Arch 相同。
  detection_skill: cpu_analysis
- id: fabric_mount_overhead
  name: Fabric mount 阶段开销
  description: 'Fabric mount 阶段在 main thread 执行 View 创建/更新。

    FlatList 虚拟化不足 / 大量同时 mount 的 View 让这一段超 budget。

    '
  detection_skill: app_frame_production
- id: turbomodule_synchronous_blocking
  name: TurboModule 同步调用阻塞 JS
  description: 'TurboModule 同步调用让 JS 线程阻塞等待 native 完成。

    滥用同步调用会让 JS 线程变成主要瓶颈。

    '
  detection_skill: cpu_analysis
- id: hermes_gc_pause
  name: Hermes GC pause
  description: 同 Old Arch — Hermes 大 heap 下可能 ms 级停顿。
  detection_skill: gc_analysis
recommended_skills:
- cpu_analysis
- gc_analysis
- scrolling_analysis
```
