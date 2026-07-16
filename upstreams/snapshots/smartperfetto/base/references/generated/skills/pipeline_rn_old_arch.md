GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/rn_old_arch.skill.yaml
Source SHA-256: 8fe98e016f146e01ca6d726872aa432c1de7b609f7b2161b3cf14bf25223cbbd
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# React Native Old Arch (Paper + Bridge)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_rn_old_arch
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: RN_OLD_ARCH_HWUI
display_name: React Native Old Arch (Paper + Bridge)
description: RN 老架构：JavaScriptCore/Hermes + Bridge JSON 序列化 + Shadow tree + Yoga + 宿主 HWUI
icon: react
family: webview
doc_path: rendering_pipelines/S14_react_native_type.md
s_article_ref: S14
four_features:
  producer_threads:
  - mqt_js
  - mqt_native_modules
  - mqt_shadow_queue
  consumer_threads:
  - main
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: JS_TO_BRIDGE_TO_SHADOW_TREE_TO_HOST_HWUI
  extra_rhythm_sources:
  - js_bridge_dispatch
deviation_anchors: rn_bridge_anchor_2_3_at_js_layer
threads_evolution: '线程名（社区版习惯，可能随 RN 版本/fork/定制改名）：

  - mqt_js: JavaScript 线程（执行 React 业务逻辑）

  - mqt_native_modules: Native module 调用线程

  - mqt_shadow_queue: Shadow thread / Layout thread（Yoga 计算）

  - main + RenderThread: 标准 Android HWUI

  '
```

## Detection

```yaml
required_signals:
- thread_pattern: mqt_*
  min_count: 1
scoring_signals:
- signal: has_mqt_js
  thread_pattern: mqt_js*
  weight: 50
- signal: has_mqt_native_modules
  thread_pattern: mqt_native_modules*
  weight: 30
- signal: has_mqt_shadow
  thread_pattern: mqt_shadow*
  weight: 25
- signal: has_yoga_layout
  slice_pattern: '*Yoga*'
  weight: 15
- signal: has_native_to_js
  slice_pattern: '*NativeToJsBridge*'
  weight: 10
- signal: has_js_to_native
  slice_pattern: '*JsToNativeBridge*'
  weight: 10
- signal: has_uimanager
  slice_pattern: '*UIManager*dispatchViewUpdates*'
  weight: 12
exclude_if:
- slice_pattern: '*FabricUIManager*'
```

## Teaching model

```yaml
source: rendering_pipelines/S14_react_native_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: js_thread_blocking
  name: JS 线程阻塞
  description: '任何 JS 侧阻塞（业务逻辑慢、Hermes/JSC GC pause、大列表 render）都会拖后续动画/输入。

    Animated API JS driver 每帧过 JS 线程，JS 繁忙时动画直接掉帧。

    '
  detection_skill: cpu_analysis
- id: bridge_serialization_overhead
  name: Bridge 序列化开销累积
  description: 'Old Arch 频繁小粒度跨边界调用（JS ↔ Native）累积 JSON 序列化成本。

    典型表现：mqt_js / mqt_native_modules 上密集小 slice。修复：批量化、调用合并。

    '
  detection_skill: cpu_analysis
- id: yoga_layout_deep_nesting
  name: Yoga layout 深嵌套或复杂 flex 规则
  description: '深嵌套 View 树或复杂 flex 规则让 Yoga layout 在 mqt_shadow_queue 上耗时膨胀。

    '
  detection_skill: app_frame_production
- id: hermes_gc_pause
  name: Hermes GC pause
  description: 'Hermes 大 heap 下可能 ms 级停顿。Trace 上看 mqt_js 线程的 GC slice。

    '
  detection_skill: gc_analysis
- id: animated_js_driver_jank
  name: Animated API JS driver 掉帧
  description: 'Animated API JS driver 每帧过 JS 线程，JS 繁忙时动画直接掉帧。

    建议改用 Native driver（但 Native driver 不支持 layout 属性如 width/height）。

    '
  detection_skill: scrolling_analysis
recommended_skills:
- cpu_analysis
- gc_analysis
- scrolling_analysis
```
