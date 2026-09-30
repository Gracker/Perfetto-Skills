GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/app/systemui_module.skill.yaml
Source SHA-256: 878a322c6ecb8d008c5c1eb3a818f63e55dfb38cdd5a00236fef47da90c6bd0a
# SystemUI 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: systemui_module
version: '1.0'
type: composite
category: app
```

## Metadata

```yaml
display_name: SystemUI 分析
description: 分析状态栏、通知中心、快捷设置和导航栏性能
tags:
- app
- systemui
- statusbar
- notification
- quicksettings
- navbar
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
```

## Module contract

```yaml
layer: app
component: SystemUI
subsystems:
- status_bar
- notification_shade
- quick_settings
- navigation_bar
- lock_screen
- volume_dialog
```

## Ordered execution

### SystemUI 进程识别

- ID: `systemui_process`
- Type: `atomic`
- SQL: [`../sql/systemui_module/systemui_process.sql`](../sql/systemui_module/systemui_process.sql)

```yaml
id: systemui_process
type: atomic
display:
  level: detail
  layer: overview
  title: SystemUI 进程
save_as: systemui_process
```
### SystemUI 主线程概览

- ID: `systemui_main_thread`
- Type: `atomic`
- SQL: [`../sql/systemui_module/systemui_main_thread.sql`](../sql/systemui_module/systemui_main_thread.sql)

```yaml
id: systemui_main_thread
type: atomic
display:
  level: key
  layer: overview
  title: SystemUI 主线程活动
save_as: systemui_main_thread
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
on_empty: 未找到 SystemUI 进程数据
```
### SystemUI 帧渲染

- ID: `systemui_frames`
- Type: `atomic`
- SQL: [`../sql/systemui_module/systemui_frames.sql`](../sql/systemui_module/systemui_frames.sql)

```yaml
id: systemui_frames
type: atomic
display:
  level: key
  layer: overview
  title: SystemUI 帧统计
save_as: systemui_frames
synthesize: true
```
### 状态栏活动

- ID: `statusbar_activities`
- Type: `atomic`
- SQL: [`../sql/systemui_module/statusbar_activities.sql`](../sql/systemui_module/statusbar_activities.sql)

```yaml
id: statusbar_activities
type: atomic
display:
  level: detail
  layer: list
  title: 状态栏活动
save_as: statusbar_activities
```
### 通知中心活动

- ID: `notification_shade`
- Type: `atomic`
- SQL: [`../sql/systemui_module/notification_shade.sql`](../sql/systemui_module/notification_shade.sql)

```yaml
id: notification_shade
type: atomic
display:
  level: detail
  layer: list
  title: 通知中心活动
save_as: notification_shade
```
### 快捷设置活动

- ID: `quick_settings`
- Type: `atomic`
- SQL: [`../sql/systemui_module/quick_settings.sql`](../sql/systemui_module/quick_settings.sql)

```yaml
id: quick_settings
type: atomic
display:
  level: detail
  layer: list
  title: 快捷设置活动
save_as: quick_settings
```
### 导航栏活动

- ID: `navigation_activities`
- Type: `atomic`
- SQL: [`../sql/systemui_module/navigation_activities.sql`](../sql/systemui_module/navigation_activities.sql)

```yaml
id: navigation_activities
type: atomic
display:
  level: detail
  layer: list
  title: 导航栏活动
save_as: navigation_activities
```
### 锁屏活动

- ID: `lockscreen_activities`
- Type: `atomic`
- SQL: [`../sql/systemui_module/lockscreen_activities.sql`](../sql/systemui_module/lockscreen_activities.sql)

```yaml
id: lockscreen_activities
type: atomic
display:
  level: detail
  layer: list
  title: 锁屏活动
save_as: lockscreen_activities
```
### SystemUI Binder 调用

- ID: `systemui_binder`
- Type: `atomic`
- SQL: [`../sql/systemui_module/systemui_binder.sql`](../sql/systemui_module/systemui_binder.sql)

```yaml
id: systemui_binder
type: atomic
display:
  level: detail
  layer: list
  title: SystemUI Binder 调用
save_as: systemui_binder
```
### 音量对话框

- ID: `volume_dialog`
- Type: `atomic`
- SQL: [`../sql/systemui_module/volume_dialog.sql`](../sql/systemui_module/volume_dialog.sql)

```yaml
id: volume_dialog
type: atomic
display:
  level: detail
  layer: list
  title: 音量对话框
save_as: volume_dialog
optional: true
```
### SystemUI 诊断

- ID: `systemui_diagnosis`
- Type: `diagnostic`

```yaml
id: systemui_diagnosis
type: diagnostic
inputs:
- systemui_frames
- systemui_main_thread
- notification_shade
- quick_settings
- navigation_activities
- systemui_binder
rules:
- condition: systemui_frames.data[0]?.jank_rate_pct > 5
  diagnosis: SystemUI 卡顿率 ${systemui_frames.data[0]?.jank_rate_pct}%，影响系统 UI 体验
  confidence: high
  suggestions:
  - 检查通知中心动画性能
  - 优化快捷设置 Tile 响应
  - 减少主线程耗时操作
  evidence_fields:
  - systemui_frames.data[0]?.jank_rate_pct
  - systemui_frames.data[0]?.jank_frames
  - systemui_frames.data[0]?.total_frames
- condition: systemui_main_thread.data[0]?.max_ms > 100
  diagnosis: 'SystemUI 主线程存在耗时操作: ${systemui_main_thread.data[0]?.activity} 最长 ${systemui_main_thread.data[0]?.max_ms}ms'
  confidence: high
  suggestions:
  - 将耗时操作移至后台线程
  - 优化 UI 更新逻辑
  evidence_fields:
  - systemui_main_thread.data[0]?.activity
  - systemui_main_thread.data[0]?.max_ms
- condition: notification_shade.data[0]?.max_ms > 50
  diagnosis: '通知中心活动耗时较高: ${notification_shade.data[0]?.shade_event} 最长 ${notification_shade.data[0]?.max_ms}ms'
  confidence: medium
  suggestions:
  - 优化通知渲染
  - 减少通知展开时的计算
  - 检查是否有复杂的自定义通知视图
  evidence_fields:
  - notification_shade.data[0]?.shade_event
  - notification_shade.data[0]?.max_ms
- condition: quick_settings.data[0]?.max_ms > 50
  diagnosis: '快捷设置耗时较高: ${quick_settings.data[0]?.qs_event} 最长 ${quick_settings.data[0]?.max_ms}ms'
  confidence: medium
  suggestions:
  - 优化 Tile 状态查询
  - 减少 Tile 刷新频率
  evidence_fields:
  - quick_settings.data[0]?.qs_event
  - quick_settings.data[0]?.max_ms
- condition: navigation_activities.data[0]?.max_ms > 32
  diagnosis: '导航手势响应较慢: ${navigation_activities.data[0]?.nav_event} 最长 ${navigation_activities.data[0]?.max_ms}ms'
  confidence: medium
  suggestions:
  - 检查手势检测逻辑
  - 优化动画实现
  evidence_fields:
  - navigation_activities.data[0]?.nav_event
  - navigation_activities.data[0]?.max_ms
- condition: systemui_binder.data[0]?.max_ms > 50
  diagnosis: 'SystemUI 存在耗时 Binder 调用: ${systemui_binder.data[0]?.binder_call} 最长 ${systemui_binder.data[0]?.max_ms}ms'
  confidence: medium
  suggestions:
  - 检查是否可以异步执行
  - 缓存 Binder 调用结果
  evidence_fields:
  - systemui_binder.data[0]?.binder_call
  - systemui_binder.data[0]?.max_ms
display:
  level: key
  layer: overview
  title: SystemUI 诊断结果
```
