GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/chrome_scroll_jank_frame_timeline.skill.yaml
Source SHA-256: 2aa88e4f3cc40101c7a97eefeb3cfa517026c5c827e22d0cd8894af2a57da2a4
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# Chrome Scroll Jank / Frame Timeline

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: chrome_scroll_jank_frame_timeline
version: '1.0'
type: atomic
category: scrolling
tier: B
```

## Metadata

```yaml
display_name: Chrome Scroll Jank / Frame Timeline
description: 分析 Chrome scroll jank v3/v4、scroll frame stages 与 Chrome preferred frame timeline availability
icon: chrome
tags:
- chrome
- scroll
- jank
- frame_timeline
- upstream
```

## Triggers

```yaml
keywords:
  zh:
  - Chrome 卡顿
  - Chrome 滑动
  - WebView Chrome
  - scroll jank v4
  - preferred frame timeline
  en:
  - chrome scroll jank
  - scroll jank v4
  - chrome frame timeline
  - preferred frame timeline
patterns:
- .*Chrome.*(scroll|jank|frame timeline).*
- .*(scroll jank v4|preferred frame timeline).*
```

## Prerequisites

```yaml
modules:
- chrome.chrome_scrolls
- chrome.chrome_scrolls_v4
- chrome.scroll_jank.scroll_jank_intervals
- chrome.scroll_jank_v4
- chrome.scroll_jank_tagging
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
- name: min_janky_frames
  type: integer
  required: false
  default: 1
  description: v3 scroll summary 至少包含的 janky frame 数
```

## Ordered execution

### Chrome Scroll 数据可用性

- ID: `chrome_trace_availability`
- Type: `atomic`
- SQL: [`../sql/chrome_scroll_jank_frame_timeline/chrome_trace_availability.sql`](../sql/chrome_scroll_jank_frame_timeline/chrome_trace_availability.sql)

```yaml
id: chrome_trace_availability
type: atomic
display:
  level: key
  layer: overview
  title: Chrome Scroll 数据可用性
  columns:
  - name: chrome_scroll_count
    label: Scroll 数
    type: number
  - name: chrome_scroll_stats_count
    label: v3 统计数
    type: number
  - name: chrome_scroll_v4_frame_count
    label: v4 Frame 数
    type: number
  - name: chrome_scroll_v4_jank_count
    label: v4 Jank 数
    type: number
  - name: extend_vsync_count
    label: Extend_VSync 数
    type: number
  - name: preferred_frame_timeline_count
    label: Preferred Timeline 数
    type: number
  - name: status
    label: 状态
    type: string
save_as: chrome_trace_availability
```
### Chrome Scroll Jank v3 汇总

- ID: `chrome_scroll_v3_summary`
- Type: `atomic`
- SQL: [`../sql/chrome_scroll_jank_frame_timeline/chrome_scroll_v3_summary.sql`](../sql/chrome_scroll_jank_frame_timeline/chrome_scroll_v3_summary.sql)

```yaml
id: chrome_scroll_v3_summary
type: atomic
optional: true
display:
  level: key
  layer: list
  title: Chrome Scroll Jank v3 汇总
  columns:
  - name: scroll_id
    label: Scroll ID
    type: number
  - name: ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ms
    label: 持续时间(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: frame_count
    label: 帧数
    type: number
  - name: presented_frame_count
    label: 呈现帧数
    type: number
  - name: janky_frame_count
    label: Janky 帧
    type: number
  - name: missed_vsyncs
    label: Missed VSync
    type: number
  - name: janky_frame_percent
    label: Jank 占比
    type: percentage
    format: percentage
save_as: chrome_scroll_v3_summary
```
### Chrome Scroll Jank v4 帧明细

- ID: `chrome_scroll_v4_janky_frames`
- Type: `atomic`
- SQL: [`../sql/chrome_scroll_jank_frame_timeline/chrome_scroll_v4_janky_frames.sql`](../sql/chrome_scroll_jank_frame_timeline/chrome_scroll_v4_janky_frames.sql)

```yaml
id: chrome_scroll_v4_janky_frames
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Chrome Scroll Jank v4 帧明细
  columns:
  - name: frame_id
    label: Frame ID
    type: number
  - name: scroll_id
    label: Scroll ID
    type: number
  - name: ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ms
    label: 耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: vsyncs_since_previous_frame
    label: 距上帧 VSync
    type: number
  - name: first_scroll_update_type
    label: 首个输入类型
    type: string
  - name: damage_type
    label: Damage 类型
    type: string
  - name: real_abs_total_raw_delta_pixels
    label: 输入 Delta(px)
    type: number
  - name: jank_tags
    label: Jank 标签
    type: string
save_as: chrome_scroll_v4_janky_frames
```
### Chrome Preferred FrameTimeline

- ID: `chrome_preferred_frame_timeline`
- Type: `atomic`
- SQL: [`../sql/chrome_scroll_jank_frame_timeline/chrome_preferred_frame_timeline.sql`](../sql/chrome_scroll_jank_frame_timeline/chrome_preferred_frame_timeline.sql)

```yaml
id: chrome_preferred_frame_timeline
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Chrome Preferred FrameTimeline
  columns:
  - name: extend_vsync_slice_id
    label: Extend_VSync Slice
    type: number
  - name: ts
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: frame_ts
    label: Frame Time
    type: timestamp
    unit: ns
  - name: preferred_timeline_index
    label: Preferred Index
    type: number
  - name: chrome_preferred_vsync_id
    label: Chrome Preferred VSync
    type: number
  - name: preferred_source
    label: Preferred 来源
    type: string
save_as: chrome_preferred_frame_timeline
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: chrome_trace_availability
  description: Chrome scroll/jank/frame timeline 数据可用性
- name: chrome_scroll_v3_summary
  description: Chrome scroll jank v3 按 scroll 汇总
- name: chrome_scroll_v4_janky_frames
  description: Chrome scroll jank v4 janky frame 明细
- name: chrome_preferred_frame_timeline
  description: Chrome preferred frame timeline availability 与候选数
```
