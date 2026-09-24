GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
Source SHA-256: 4b5eabe1c5639d55456e498bdf6125fda0f49f1b49a216536b0f7ffde8cf04c7
Source commit: e7ff73a937cc66d89fdc69d59728025734759acd
# Consumer Jank 检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: consumer_jank_detection
version: '1.2'
type: atomic
category: rendering
tier: A
```

## Metadata

```yaml
display_name: Consumer Jank 检测
description: 检测 Consumer (SurfaceFlinger) 侧的卡顿
icon: warning
tags:
- jank
- consumer
- surfaceflinger
- atomic
pipeline_aware: true
pipeline_aware_note: '本 skill 已暴露 pipeline_id 可选输入。

  当前实现按 layer_name 过滤通用判断（pipeline-agnostic），未来可按 pipeline_id 切换 SQL：

  - Flutter: 1.ui jank（Animator::BeginFrame 超 budget）vs 1.raster jank（Rasterizer 超 budget）分开计

  - Camera: 多路输出 back-pressure 归因（preview/analysis/record）

  - Video: codec underflow（releaseOutputBuffer pool 耗尽）vs HWC overlay degradation

  - Game: 三线程 lag 归因（GameThread/RenderThread/RHIThread）

  '
```

## Triggers

```yaml
keywords:
  zh:
  - 消费端卡顿
  - present interval
  - SurfaceFlinger
  - 显示端卡顿
  - 帧呈现
  en:
  - consumer jank
  - present interval
  - surfaceflinger
  - display jank
patterns:
- .*(消费端|显示端).*(卡顿|掉帧).*
- .*(consumer|present|display).*jank.*
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
modules:
- android.frames.timeline
- android.frames.jank_type
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名
- name: layer_name
  type: string
  required: false
  description: Layer 名称（可选，用于精确匹配）
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: pipeline_id
  type: string
  required: false
  description: 'Pipeline ID (Phase F: pipeline-aware optional input; 当前实现 pipeline-agnostic, 未来按 pipeline 切换 SQL)'
```

## Ordered execution

### VSync 配置

- ID: `vsync_config`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/vsync_config.sql`](../sql/consumer_jank_detection/vsync_config.sql)

```yaml
id: vsync_config
type: atomic
save_as: vsync_config
```
### 呈现节奏与晚拍交叉核验

- ID: `presentation_cadence_audit`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/presentation_cadence_audit.sql`](../sql/consumer_jank_detection/presentation_cadence_audit.sql)

```yaml
id: presentation_cadence_audit
type: atomic
display:
  level: summary
  layer: overview
  title: Buffer Stuffing 标签与实际呈现节奏（不等同反压诊断）
  columns:
  - name: layer_name
    label: 图层
    type: string
  - name: burst_id
    label: 连续片段
    type: number
  - name: total_frames
    label: 有效呈现帧数
    type: number
  - name: raw_buffer_stuffing_frames
    label: 原始 Stuffing 标签
    type: number
  - name: buffer_stuffing_label_pct
    label: 标签占比
    type: percentage
  - name: steady_late_frames
    label: 匀速晚拍帧（信息性）
    type: number
  - name: vsync_period_ns
    label: 观测 VSync 周期(ns)
    type: number
  - name: cadence_status
    label: 呈现节奏
    type: string
  - name: cadence_gap_frames
    label: 超过 1.5 VSync 的间隔
    type: number
  - name: dropped_frames
    label: 丢弃帧
    type: number
  - name: missed_frame_type_frames
    label: 原始 Missed Frame 标签
    type: number
  - name: late_present_frames
    label: Late Present 标签
    type: number
  - name: avg_present_interval_ms
    label: 平均呈现间隔(ms)
    type: number
  - name: min_late_vsyncs
    label: 正向晚拍最小 VSync
    type: number
  - name: max_late_vsyncs
    label: 正向晚拍最大 VSync
    type: number
  - name: manual_review_required
    label: 需要机制复核
    type: number
  - name: claim_boundary
    label: 结论边界
    type: string
save_as: presentation_cadence_audit
```
### 消费端掉帧检测

- ID: `consumer_jank_frames`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/consumer_jank_frames.sql`](../sql/consumer_jank_detection/consumer_jank_frames.sql)

```yaml
id: consumer_jank_frames
type: atomic
display:
  level: detail
  title: 消费端异常及待核验帧
  columns:
  - name: frame_id
    label: 帧ID
    type: string
  - name: layer_name
    label: 图层
    type: string
  - name: ts_str
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: ts_sec
    label: 时间(s)
    type: number
  - name: dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: token_gap
    label: Token跳跃
    type: number
  - name: vsync_missed
    label: 跳帧数
    type: number
  - name: interval_ms
    label: 间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: app_jank_type
    label: App标记
    type: string
  - name: present_type
    label: 呈现状态
    type: string
  - name: jank_severity
    label: 严重程度
    type: string
  - name: delay_source
    label: 延迟来源
    type: string
    description: app_late=应用渲染超时, sf_late=SF/显示延迟, buffer_stuffing=缓冲区满
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: claim_boundary
    label: 结论边界
    type: string
save_as: consumer_jank_frames
```
### 消费端混合呈现信号汇总

- ID: `consumer_jank_summary`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/consumer_jank_summary.sql`](../sql/consumer_jank_detection/consumer_jank_summary.sql)

```yaml
id: consumer_jank_summary
type: atomic
display:
  level: summary
  title: 消费端混合呈现异常（不等同可见卡顿）
  columns:
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: consumer_jank_frames
    label: 混合呈现异常帧
    type: number
    format: compact
  - name: unassessed_frames
    label: 呈现间隔待核验帧
    type: number
  - name: smooth_frames
    label: 未命中消费异常帧
    type: number
    format: compact
  - name: consumer_jank_rate
    label: 混合呈现异常率
    type: percentage
    format: percentage
  - name: max_vsync_missed
    label: 最大跳帧
    type: number
  - name: raw_buffer_stuffing_frames
    label: 含 Stuffing 原始标签帧
    type: number
  - name: manual_review_required
    label: 需呈现节奏与机制复核
    type: number
  - name: rating
    label: 评级
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
  - name: claim_boundary
    label: 结论边界
    type: string
save_as: consumer_jank_summary
```
### 掉帧严重程度分布

- ID: `jank_severity_distribution`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/jank_severity_distribution.sql`](../sql/consumer_jank_detection/jank_severity_distribution.sql)

```yaml
id: jank_severity_distribution
type: atomic
display:
  level: detail
  title: 掉帧严重程度分布
  columns:
  - name: severity
    label: 严重程度
    type: string
  - name: count
    label: 帧数
    type: number
    format: compact
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
save_as: jank_severity_distribution
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: presentation_cadence_audit
  description: 先交叉核验原始 Stuffing 标签与呈现节奏；steady_late 为信息性晚拍，不取消 Deadline/Dropped 证据；manual_review_required 时不得仅凭标签占比诊断缓冲反压
- name: consumer_jank_frames
  description: 消费端异常及待核验帧；非 Stuffing Late 为框架信号，可见节奏须结合 presentation_cadence_audit
- name: consumer_jank_summary
  description: 消费端掉帧统计汇总
- name: jank_severity_distribution
  description: 掉帧严重程度分布
```
