GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/app/launcher_module.skill.yaml
Source SHA-256: 09423f22ca1cc723d498d6e9ecfbfb935d5cf177154c5eab813f3bf7d0bcef40
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# Launcher 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: launcher_module
version: '1.0'
type: composite
category: app
```

## Metadata

```yaml
display_name: Launcher 分析
description: 分析桌面启动器性能、应用启动和小部件更新
tags:
- app
- launcher
- home
- widget
- wallpaper
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
- name: target_package
  type: string
  required: false
  description: Target app package to analyze launch timing
```

## Module contract

```yaml
layer: app
component: Launcher
subsystems:
- home_screen
- all_apps
- widgets
- wallpaper
- app_launch
relatedModules:
- framework_ams
- framework_wms
- framework_surfaceflinger
- app_systemui
```

## Dialogue guidance

```yaml
capabilities:
- id: launcher_performance
  questionTemplate: What is the Launcher performance?
  requiredParams: []
  description: Analyze overall launcher performance
- id: app_launch_from_launcher
  questionTemplate: How long did it take to launch {target_package} from launcher?
  requiredParams:
  - target_package
  description: Analyze app launch timing from home screen
- id: widget_update_analysis
  questionTemplate: Are widgets causing performance issues?
  requiredParams: []
  description: Analyze widget update performance
- id: launcher_frame_analysis
  questionTemplate: Is launcher rendering smoothly?
  requiredParams: []
  description: Analyze launcher frame rendering
findingsSchema:
- id: slow_launcher_startup
  severity: warning
  titleTemplate: 'Slow launcher startup: {startup_ms}ms'
  descriptionTemplate: Launcher took {startup_ms}ms to become interactive
  evidenceFields:
  - startup_ms
  - cold_or_warm
  - blocking_component
- id: slow_app_launch
  severity: warning
  titleTemplate: 'Slow app launch from launcher: {launch_ms}ms'
  descriptionTemplate: Launching {target_package} took {launch_ms}ms
  evidenceFields:
  - target_package
  - launch_ms
  - icon_tap_ts
  - app_visible_ts
- id: widget_update_slow
  severity: warning
  titleTemplate: 'Slow widget update: {widget_name} took {update_ms}ms'
  descriptionTemplate: Widget update blocking main thread
  evidenceFields:
  - widget_name
  - update_ms
  - update_count
- id: launcher_jank
  severity: warning
  titleTemplate: 'Launcher jank: {jank_count} frames dropped'
  descriptionTemplate: Home screen rendering has {jank_count} janky frames
  evidenceFields:
  - jank_count
  - total_frames
  - jank_rate_pct
- id: wallpaper_rendering_slow
  severity: info
  titleTemplate: 'Wallpaper rendering slow: {render_ms}ms'
  descriptionTemplate: Live wallpaper or wallpaper transition taking too long
  evidenceFields:
  - render_ms
  - wallpaper_type
suggestionsSchema:
- id: check_ams_for_launch
  condition: slow_app_launch == true
  targetModule: ams_module
  questionTemplate: What is the startup timing breakdown for {target_package}?
  paramsMapping:
    package: target_package
  priority: 1
- id: check_wms_for_transition
  condition: slow_app_launch == true
  targetModule: wms_module
  questionTemplate: What was the window transition timing?
  paramsMapping: {}
  priority: 2
- id: check_scheduler_for_launcher
  condition: launcher_jank == true
  targetModule: scheduler_module
  questionTemplate: Was launcher main thread getting enough CPU time?
  paramsMapping: {}
  priority: 1
```

## Ordered execution

### Launcher 进程识别

- ID: `launcher_process`
- Type: `atomic`
- SQL: [`../sql/launcher_module/launcher_process.sql`](../sql/launcher_module/launcher_process.sql)

```yaml
id: launcher_process
type: atomic
display:
  level: detail
  layer: overview
  title: Launcher 进程
save_as: launcher_process
```
### Launcher 主线程概览

- ID: `launcher_main_thread`
- Type: `atomic`
- SQL: [`../sql/launcher_module/launcher_main_thread.sql`](../sql/launcher_module/launcher_main_thread.sql)

```yaml
id: launcher_main_thread
type: atomic
display:
  level: key
  layer: overview
  title: Launcher 主线程活动
save_as: launcher_main_thread
synthesize:
  role: overview
  fields:
  - key: activity
    label: 活动
  - key: count
    label: 次数
  - key: total_ms
    label: 总耗时
    format: '{{value}}ms'
on_empty: 未找到 Launcher 进程或主线程数据
```
### Launcher 帧渲染

- ID: `launcher_frames`
- Type: `atomic`
- SQL: [`../sql/launcher_module/launcher_frames.sql`](../sql/launcher_module/launcher_frames.sql)

```yaml
id: launcher_frames
type: atomic
display:
  level: key
  layer: overview
  title: Launcher 帧统计
save_as: launcher_frames
synthesize: true
```
### Widget 活动

- ID: `widget_activities`
- Type: `atomic`
- SQL: [`../sql/launcher_module/widget_activities.sql`](../sql/launcher_module/widget_activities.sql)

```yaml
id: widget_activities
type: atomic
display:
  level: detail
  layer: list
  title: Widget 活动
save_as: widget_activities
```
### 应用启动事件

- ID: `app_launch_events`
- Type: `atomic`
- SQL: [`../sql/launcher_module/app_launch_events.sql`](../sql/launcher_module/app_launch_events.sql)

```yaml
id: app_launch_events
type: atomic
display:
  level: detail
  layer: list
  title: 应用启动事件
save_as: app_launch_events
```
### 壁纸渲染

- ID: `wallpaper_rendering`
- Type: `atomic`
- SQL: [`../sql/launcher_module/wallpaper_rendering.sql`](../sql/launcher_module/wallpaper_rendering.sql)

```yaml
id: wallpaper_rendering
type: atomic
display:
  level: detail
  layer: list
  title: 壁纸渲染
save_as: wallpaper_rendering
optional: true
```
### All Apps 抽屉

- ID: `all_apps_drawer`
- Type: `atomic`
- SQL: [`../sql/launcher_module/all_apps_drawer.sql`](../sql/launcher_module/all_apps_drawer.sql)

```yaml
id: all_apps_drawer
type: atomic
display:
  level: detail
  layer: list
  title: All Apps 抽屉
save_as: all_apps_drawer
```
### Launcher Binder 调用

- ID: `launcher_binder_calls`
- Type: `atomic`
- SQL: [`../sql/launcher_module/launcher_binder_calls.sql`](../sql/launcher_module/launcher_binder_calls.sql)

```yaml
id: launcher_binder_calls
type: atomic
display:
  level: detail
  layer: list
  title: Launcher Binder 调用
save_as: launcher_binder_calls
```
### Launcher 诊断

- ID: `launcher_diagnosis`
- Type: `diagnostic`

```yaml
id: launcher_diagnosis
type: diagnostic
inputs:
- launcher_frames
- launcher_main_thread
- widget_activities
- launcher_binder_calls
rules:
- condition: launcher_frames.data[0]?.jank_rate_pct > 5
  diagnosis: Launcher 卡顿率 ${launcher_frames.data[0]?.jank_rate_pct}%，影响桌面体验
  confidence: high
  suggestions:
  - 检查主线程耗时操作
  - 优化 Widget 更新频率
  - 减少同步 Binder 调用
  evidence_fields:
  - launcher_frames.data[0]?.jank_rate_pct
  - launcher_frames.data[0]?.jank_frames
  - launcher_frames.data[0]?.total_frames
- condition: launcher_main_thread.data[0]?.max_ms > 100
  diagnosis: 'Launcher 主线程存在耗时操作: ${launcher_main_thread.data[0]?.activity} 最长 ${launcher_main_thread.data[0]?.max_ms}ms'
  confidence: high
  suggestions:
  - 将耗时操作移至后台线程
  - 使用异步加载
  evidence_fields:
  - launcher_main_thread.data[0]?.activity
  - launcher_main_thread.data[0]?.max_ms
- condition: widget_activities.data[0]?.total_ms > 100
  diagnosis: 'Widget 活动耗时较高: ${widget_activities.data[0]?.widget_activity} 共 ${widget_activities.data[0]?.total_ms}ms'
  confidence: medium
  suggestions:
  - 减少 Widget 更新频率
  - 简化 Widget 布局
  - 避免在 Widget 中使用复杂视图
  evidence_fields:
  - widget_activities.data[0]?.widget_activity
  - widget_activities.data[0]?.total_ms
- condition: launcher_binder_calls.data[0]?.max_ms > 50
  diagnosis: 'Launcher 存在耗时 Binder 调用: ${launcher_binder_calls.data[0]?.binder_call} 最长 ${launcher_binder_calls.data[0]?.max_ms}ms'
  confidence: medium
  suggestions:
  - 检查是否可以异步执行
  - 减少主线程 Binder 调用
  evidence_fields:
  - launcher_binder_calls.data[0]?.binder_call
  - launcher_binder_calls.data[0]?.max_ms
display:
  level: key
  layer: overview
  title: Launcher 诊断结果
```
