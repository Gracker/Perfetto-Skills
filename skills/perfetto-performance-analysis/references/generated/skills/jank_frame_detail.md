GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/jank_frame_detail.skill.yaml
Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 掉帧详情分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: jank_frame_detail
version: '2.0'
type: composite
category: rendering
tier: S
```

## Metadata

```yaml
display_name: 掉帧详情分析
description: 分析特定掉帧的详细原因
icon: broken_image
tags:
- jank
- detail
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 卡顿帧
  - 帧详情
  - 单帧根因
  - 掉帧原因
  - jank 详情
  en:
  - jank frame detail
  - frame root cause
  - dropped frame detail
patterns:
- .*(卡顿帧|掉帧).*(详情|根因|原因).*
- .*jank.*frame.*(detail|root cause).*
```

## Prerequisites

```yaml
modules:
- android.binder
- android.slices
- android.monitor_contention
- android.garbage_collection
- android.gpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 帧开始时间戳(ns)，优先使用
- name: end_ts
  type: timestamp
  required: false
  description: 帧结束时间戳(ns)
- name: frame_ts
  type: timestamp
  required: false
  description: 帧开始时间戳(ns)，兼容旧接口，等同于 start_ts
- name: frame_dur
  type: duration
  required: false
  description: 帧持续时间(ns)，兼容旧接口，用于计算 end_ts
- name: main_start_ts
  type: timestamp
  required: false
- name: main_end_ts
  type: timestamp
  required: false
- name: main_dur_ms
  type: number
  required: false
- name: render_start_ts
  type: timestamp
  required: false
- name: render_end_ts
  type: timestamp
  required: false
- name: render_dur_ms
  type: number
  required: false
- name: package
  type: string
  required: false
- name: pid
  type: integer
  required: false
- name: frame_id
  type: integer
  required: false
  description: 帧 ID，可选
- name: frame_index
  type: integer
  required: false
- name: jank_type
  type: string
  required: false
  description: 掉帧类型，可选，默认 'Unknown'
- name: dur_ms
  type: number
  required: false
  description: 帧耗时(ms)，可选，可从 start_ts/end_ts 计算
- name: session_id
  type: integer
  required: false
- name: layer_name
  type: string
  required: false
- name: token_gap
  type: integer
  required: false
  description: display_frame_token 跳跃值 (>1 表示消费端掉帧)
- name: vsync_missed
  type: integer
  required: false
  description: 跳过的 VSync 数量 (token_gap - 1)
- name: jank_responsibility
  type: string
  required: false
  description: '掉帧责任归属: APP / SF / BUFFER_STUFFING / HIDDEN / UNKNOWN'
- name: jank_cause
  type: string
  required: false
  description: 掉帧原因说明，由 scrolling_analysis 生成的中文诊断
```

## Identity requirements

```yaml
policy: required
scope: process
aliases:
- package
- process_name
rewriteTo: recommended_process_name_param
```

## Ordered execution

### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
display:
  level: hidden
optional: true
```
### Monitor Contention 数据源检测

- ID: `monitor_contention_check`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/monitor_contention_check.sql`](../sql/jank_frame_detail/monitor_contention_check.sql)

```yaml
id: monitor_contention_check
type: atomic
display: false
save_as: monitor_contention
```
### GC 数据源检测

- ID: `gc_table_check`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/gc_table_check.sql`](../sql/jank_frame_detail/gc_table_check.sql)

```yaml
id: gc_table_check
type: atomic
display: false
save_as: gc_availability
optional: true
```
### GPU 数据源检测

- ID: `gpu_table_check`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/gpu_table_check.sql`](../sql/jank_frame_detail/gpu_table_check.sql)

```yaml
id: gpu_table_check
type: atomic
display: false
save_as: gpu_availability
optional: true
```
### Binder 数据源检测

- ID: `binder_table_check`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/binder_table_check.sql`](../sql/jank_frame_detail/binder_table_check.sql)

```yaml
id: binder_table_check
type: atomic
display: false
save_as: binder_availability
optional: true
```
### 四象限分析

- ID: `quadrant_analysis`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/quadrant_analysis.sql`](../sql/jank_frame_detail/quadrant_analysis.sql)

```yaml
id: quadrant_analysis
type: atomic
optional: true
sql_fragments:
- fragments/target_threads.sql
display:
  level: key
  layer: deep
  title: 四大象限
  columns:
  - name: quadrant
    label: 象限
    type: string
  - name: name
    label: 名称
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
save_as: quadrant_data
output_schema:
  type: array
  items:
    quadrant:
      type: string
      description: 象限标识 (如 MainThread Q1_大核运行)
    name:
      type: string
      description: 象限名称
    dur_ms:
      type: number
      description: 持续时间(ms)
    percentage:
      type: number
      description: 百分比
```
### Binder 调用

- ID: `binder_calls`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/binder_calls.sql`](../sql/jank_frame_detail/binder_calls.sql)

```yaml
id: binder_calls
type: atomic
display:
  level: detail
  layer: deep
  title: Binder 调用
  columns:
  - name: interface
    label: 服务进程
    type: string
  - name: count
    label: 调用次数
    type: number
    format: compact
  - name: dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: sync_count
    label: 同步调用
    type: number
save_as: binder_data
optional: true
output_schema:
  type: array
  items:
    interface:
      type: string
      description: 服务端进程名
    count:
      type: number
      description: 调用次数
    dur_ms:
      type: number
      description: 总耗时(ms)
    max_ms:
      type: number
      description: 最大单次耗时(ms)
    sync_count:
      type: number
      description: 同步调用次数
```
### CPU频率

- ID: `cpu_freq_analysis`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/cpu_freq_analysis.sql`](../sql/jank_frame_detail/cpu_freq_analysis.sql)

```yaml
id: cpu_freq_analysis
type: atomic
display:
  level: detail
  layer: deep
  title: CPU 频率
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: avg_freq_mhz
    label: 平均频率
    type: number
  - name: max_freq_mhz
    label: 最大频率
    type: number
  - name: min_freq_mhz
    label: 最小频率
    type: number
save_as: freq_data
optional: true
output_schema:
  type: array
  items:
    core_type:
      type: string
      description: 核心类型 (big/little)
    avg_freq_mhz:
      type: number
      description: 平均频率(MHz)
    max_freq_mhz:
      type: number
      description: 最大频率(MHz)
    min_freq_mhz:
      type: number
      description: 最小频率(MHz)
```
### 主线程耗时操作

- ID: `main_thread_slices`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/main_thread_slices.sql`](../sql/jank_frame_detail/main_thread_slices.sql)

```yaml
id: main_thread_slices
type: atomic
display:
  level: key
  layer: deep
  title: 主线程耗时操作
  columns:
  - name: name
    label: 操作名
    type: string
  - name: dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: count
    label: 次数
    type: number
    format: compact
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
save_as: main_slices
optional: true
output_schema:
  type: array
  items:
    name:
      type: string
      description: 操作名称
    dur_ms:
      type: number
      description: 总耗时(ms)
    count:
      type: number
      description: 执行次数
    max_ms:
      type: number
      description: 最大单次耗时(ms)
    ts:
      type: string
      description: 首次时间戳(ns字符串)
```
### Choreographer resync 标记

- ID: `choreographer_resync_markers`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/choreographer_resync_markers.sql`](../sql/jank_frame_detail/choreographer_resync_markers.sql)

```yaml
id: choreographer_resync_markers
type: atomic
display:
  level: detail
  layer: deep
  title: Choreographer resync 标记
  columns:
  - name: name
    label: 标记
    type: string
  - name: target_vsync
    label: 目标 VSync
    type: string
  - name: resync_delay
    label: resync 延迟
    type: string
  - name: dur_ms
    label: 标记耗时
    type: duration
    format: duration_ms
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
save_as: resync_markers
optional: true
output_schema:
  type: array
  items:
    name:
      type: string
      description: resync marker slice name
    target_vsync:
      type: string
      description: 重新绑定到的 VSync id
    resync_delay:
      type: string
      description: marker 中记录的 resync 延迟 token
    dur_ms:
      type: number
      description: marker slice duration in ms
    ts:
      type: string
      description: timestamp ns string
```
### RenderThread 耗时操作

- ID: `render_thread_slices`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/render_thread_slices.sql`](../sql/jank_frame_detail/render_thread_slices.sql)

```yaml
id: render_thread_slices
type: atomic
display:
  level: key
  layer: deep
  title: RenderThread 耗时操作
  columns:
  - name: name
    label: 操作名
    type: string
  - name: dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: count
    label: 次数
    type: number
    format: compact
  - name: max_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: avg_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
save_as: render_slices
optional: true
output_schema:
  type: array
  items:
    name:
      type: string
      description: 操作名称
    dur_ms:
      type: number
      description: 总耗时(ms)
    count:
      type: number
      description: 执行次数
    max_ms:
      type: number
      description: 最大单次耗时(ms)
    avg_ms:
      type: number
      description: 平均耗时(ms)
    ts:
      type: string
      description: 首次时间戳(ns字符串)
```
### CPU 频率变化时间线

- ID: `cpu_freq_timeline`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/cpu_freq_timeline.sql`](../sql/jank_frame_detail/cpu_freq_timeline.sql)

```yaml
id: cpu_freq_timeline
type: atomic
display:
  level: detail
  layer: deep
  title: CPU 频率变化
  columns:
  - name: ts
    label: 时间戳
    type: timestamp
    clickAction: navigate_timeline
  - name: relative_ms
    label: 相对时间
    type: duration
    format: duration_ms
  - name: cpu
    label: CPU
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: freq_mhz
    label: 频率
    type: number
  - name: change_direction
    label: 变化
    type: enum
save_as: freq_timeline
optional: true
```
### 锁竞争分析

- ID: `lock_contention`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/lock_contention.sql`](../sql/jank_frame_detail/lock_contention.sql)

```yaml
id: lock_contention
type: atomic
display:
  level: detail
  layer: deep
  title: 锁竞争
  columns:
  - name: blocking_method
    label: 持锁方法
    type: string
    format: code
  - name: blocking_thread_name
    label: 持锁线程
    type: string
  - name: blocked_method
    label: 等锁方法
    type: string
    format: code
  - name: blocked_thread_name
    label: 等锁线程
    type: string
  - name: main_blocked
    label: 主线程被阻
    type: boolean
  - name: wait_ms
    label: 等待时间
    type: duration
    format: duration_ms
  - name: waiter_count
    label: 等待数
    type: number
save_as: lock_data
optional: true
condition: monitor_contention.data[0]?.has_monitor_contention === 1
```
### GC 影响分析

- ID: `gc_in_frame`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/gc_in_frame.sql`](../sql/jank_frame_detail/gc_in_frame.sql)

```yaml
id: gc_in_frame
type: atomic
display:
  level: detail
  layer: deep
  title: GC 与帧重叠
  columns:
  - name: gc_type
    label: GC 类型
    type: string
  - name: gc_count
    label: GC 次数
    type: number
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: overlap_ms
    label: 与帧重叠
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最大单次
    type: duration
    format: duration_ms
save_as: gc_data
optional: true
condition: gc_availability?.data?.[0]?.has_gc_table === 1
```
### IO/page-cache 等待候选分析

- ID: `io_blocking`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/io_blocking.sql`](../sql/jank_frame_detail/io_blocking.sql)

```yaml
id: io_blocking
type: atomic
display:
  level: detail
  layer: deep
  title: IO/page-cache 等待候选
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: blocked_count
    label: 阻塞次数
    type: number
  - name: total_ms
    label: 总阻塞时间
    type: duration
    format: duration_ms
  - name: max_ms
    label: 最大单次
    type: duration
    format: duration_ms
  - name: io_wait
    label: io_wait
    type: boolean
  - name: evidence_strength
    label: 证据强度
    type: string
  - name: io_cause
    label: 等待原因
    type: string
save_as: io_data
optional: true
```
### sched_latency

- ID: `sched_latency`
- Type: `skill`

```yaml
id: sched_latency
skill: sched_latency_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
save_as: sched_data
optional: true
```
### task_migration

- ID: `task_migration`
- Type: `skill`

```yaml
id: task_migration
skill: task_migration_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
save_as: migration_data
optional: true
```
### gpu_render

- ID: `gpu_render`
- Type: `skill`

```yaml
id: gpu_render
skill: gpu_render_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
save_as: gpu_data
optional: true
condition: gpu_availability?.data?.[0]?.has_gpu_slices === 1
```
### binder_blocking

- ID: `binder_blocking`
- Type: `skill`

```yaml
id: binder_blocking
skill: binder_blocking_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
save_as: binder_blocking_data
optional: true
condition: binder_availability?.data?.[0]?.has_binder_table === 1
```
### cpu_throttling

- ID: `cpu_throttling`
- Type: `skill`

```yaml
id: cpu_throttling
skill: cpu_throttling_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: throttling_data
optional: true
```
### cpu_cluster_load

- ID: `cpu_cluster_load`
- Type: `skill`

```yaml
id: cpu_cluster_load
skill: cpu_cluster_load_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: cluster_load_data
optional: true
```
### page_fault

- ID: `page_fault`
- Type: `skill`

```yaml
id: page_fault
skill: page_fault_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  package: ${package}
save_as: page_fault_data
optional: true
```
### sf_composition

- ID: `sf_composition`
- Type: `skill`

```yaml
id: sf_composition
skill: sf_composition_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: sf_data
optional: true
```
### gpu_freq

- ID: `gpu_freq`
- Type: `skill`

```yaml
id: gpu_freq
skill: gpu_freq_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: gpu_freq_data
optional: true
condition: gpu_availability?.data?.[0]?.has_gpu_freq === 1
```
### vsync_alignment

- ID: `vsync_alignment`
- Type: `skill`

```yaml
id: vsync_alignment
skill: vsync_alignment_in_range
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
save_as: vsync_data
optional: true
```
### render_pipeline

- ID: `render_pipeline`
- Type: `skill`

```yaml
id: render_pipeline
skill: render_pipeline_latency
params:
  start_ts: ${start_ts}
  end_ts: ${end_ts}
  main_start_ts: ${main_start_ts}
  main_end_ts: ${main_end_ts}
  render_start_ts: ${render_start_ts}
  render_end_ts: ${render_end_ts}
save_as: pipeline_data
optional: true
```
### 根因分析

- ID: `root_cause_summary`
- Type: `atomic`
- SQL: [`../sql/jank_frame_detail/root_cause_summary.sql`](../sql/jank_frame_detail/root_cause_summary.sql)

```yaml
id: root_cause_summary
type: atomic
sql_fragments:
- fragments/vsync_config.sql
- fragments/target_threads.sql
- fragments/thread_states_quadrant.sql
display:
  level: key
  layer: deep
  title: 🎯 根因分析
  columns:
  - name: primary_cause
    label: 主要原因
    type: string
  - name: deep_reason
    label: 为什么慢
    type: string
  - name: optimization_hint
    label: 优化方向
    type: string
  - name: reason_code
    label: 原因类型
    type: enum
  - name: secondary_info
    label: 附加信息
    type: string
  - name: confidence
    label: 置信度
    type: string
  - name: cause_type
    label: 原因类型
    type: enum
  - name: mechanism_group
    label: 机制分组
    type: enum
  - name: supply_constraint
    label: 资源问题
    type: enum
  - name: trigger_layer
    label: 触发层
    type: enum
  - name: amplification_path
    label: 放大因素
    type: enum
  - name: frame_dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
  - name: jank_type
    label: 掉帧类型
    type: string
save_as: root_cause
optional: true
```
### 帧诊断

- ID: `frame_diagnosis`
- Type: `diagnostic`

```yaml
id: frame_diagnosis
type: diagnostic
display:
  level: detail
  layer: deep
  title: 详细诊断
inputs:
- quadrant_data
- binder_data
- freq_data
- main_slices
- resync_markers
- render_slices
- freq_timeline
- lock_data
- gc_data
- io_data
- root_cause
- sched_data
- migration_data
- gpu_data
- binder_blocking_data
- throttling_data
- cluster_load_data
- page_fault_data
- sf_data
- gpu_freq_data
- vsync_data
- pipeline_data
rules:
- condition: root_cause?.data?.[0]?.primary_cause
  severity: critical
  diagnosis: ${root_cause.data[0].primary_cause}
  confidence: '${root_cause.data[0].confidence === ''高'' ? ''high'' : root_cause.data[0].confidence === ''中'' ? ''medium''
    : ''low''}'
  suggestions:
  - ${root_cause.data[0].secondary_info || '查看下方详细数据分析具体原因'}
- condition: resync_markers?.data?.length > 0
  severity: warning
  diagnosis: 检测到 Choreographer resync marker：doFrame 已重同步到后续 VSync，需结合 FrameTimeline/SF 消费证据判断是否存在 SF 未合成或帧堆积
  confidence: medium
  suggestions:
  - 不要把 resynced child slice 当作独立 doFrame 或普通业务耗时重复计数
  - 核对 jank_type、present_type、present_ts 间隔、同 layer token 和 SurfaceFlinger actual/display frame
- condition: lock_data?.data?.length > 0 && lock_data.data[0]?.wait_ms > 1
  severity: critical
  diagnosis: 锁竞争等待 ${lock_data.data[0].wait_ms}ms (${lock_data.data[0].blocking_method})
  confidence: high
  suggestions:
  - 检查持锁线程是否在做耗时操作
  - 考虑减少锁粒度或使用无锁数据结构
- condition: lock_data?.data?.length > 0 && lock_data.data[0]?.main_blocked === 1
  severity: critical
  diagnosis: 主线程被锁阻塞 (等待 ${lock_data.data[0].blocking_thread_name})
  confidence: high
  suggestions:
  - 避免在持锁时做 Binder/IO 操作
  - 考虑使用异步锁或拆分锁
- condition: io_data?.data?.length > 0 && io_data.data[0]?.total_ms > 3
  severity: critical
  diagnosis: IO/page-cache 等待候选 ${io_data.data[0].total_ms}ms (${io_data.data[0].thread_name}, ${io_data.data[0].io_cause})
  confidence: medium
  suggestions:
  - 结合文件/数据库/SharedPreferences/Provider slice 或 stack 证据确认业务根因
  - 确认后再将同步 IO 移到后台线程
- condition: io_data?.data?.length > 0 && io_data.data[0]?.total_ms > 1
  severity: warning
  diagnosis: ${io_data.data[0].thread_name} IO/page-cache 等待候选 ${io_data.data[0].total_ms}ms
  confidence: medium
  suggestions:
  - 检查帧期间是否有文件/数据库 slice、page fault 或 block I/O 证据
  - 证据闭环后再考虑内存映射、预加载或异步化
- condition: gc_data?.data?.length > 0 && gc_data.data.reduce((s, g) => s + (g.overlap_ms || 0), 0) > 3
  severity: critical
  diagnosis: GC 严重影响帧渲染：总重叠 ${gc_data.data.reduce((s, g) => s + (g.overlap_ms || 0), 0).toFixed(1)}ms
  confidence: high
  suggestions:
  - 减少帧期间的对象分配
  - 检查是否有大对象频繁创建
  - 考虑对象池化或预分配
- condition: gc_data?.data?.length > 0 && gc_data.data[0]?.overlap_ms > 1
  severity: warning
  diagnosis: GC (${gc_data.data[0].gc_type}) 与帧重叠 ${gc_data.data[0].overlap_ms}ms
  confidence: high
  suggestions:
  - 减少短生命周期对象的分配
  - 避免在 onDraw/onLayout 中创建对象
- condition: sched_data?.data?.length > 0 && sched_data.data[0]?.max_latency_ms > 5
  severity: critical
  diagnosis: '${sched_data.data[0].thread_name} 调度延迟严重: 最大 ${sched_data.data[0].max_latency_ms}ms'
  confidence: high
  suggestions:
  - 检查系统是否有高优先级进程抢占 CPU
  - 考虑提高 UI 线程优先级
  - 检查后台任务是否过于密集
- condition: sched_data?.data?.length > 0 && sched_data.data[0]?.total_runnable_ms > 3
  severity: warning
  diagnosis: ${sched_data.data[0].thread_name} Runnable 等待 ${sched_data.data[0].total_runnable_ms}ms (${sched_data.data[0].runnable_count}次)
  confidence: high
  suggestions:
  - 系统 CPU 资源紧张
  - 检查是否有密集计算任务
- condition: migration_data?.data?.length > 0 && migration_data.data[0]?.big_to_little > 2
  severity: warning
  diagnosis: ${migration_data.data[0].thread_name} 从大核迁移到小核 ${migration_data.data[0].big_to_little}次
  confidence: high
  suggestions:
  - 检查系统温控策略是否过于激进
  - 考虑绑定 UI 线程到大核
- condition: migration_data?.data?.length > 0 && migration_data.data[0]?.big_core_pct < 30
  severity: warning
  diagnosis: ${migration_data.data[0].thread_name} 大核运行占比仅 ${migration_data.data[0].big_core_pct}%
  confidence: high
  suggestions:
  - UI 线程未能获得足够大核资源
  - 检查调度器配置
- condition: gpu_data?.data?.find(g => g.operation === 'GPU Fence Wait')?.total_ms > 3
  severity: critical
  diagnosis: GPU Fence 等待 ${gpu_data.data.find(g => g.operation === 'GPU Fence Wait')?.total_ms}ms
  confidence: high
  suggestions:
  - GPU 繁忙，无法及时完成上一帧
  - 检查是否有复杂的 GPU 着色器
  - 减少过度绘制
- condition: gpu_data?.data?.find(g => g.operation === 'EGL SwapBuffers')?.max_ms > 5
  severity: warning
  diagnosis: EGL SwapBuffers 耗时 ${gpu_data.data.find(g => g.operation === 'EGL SwapBuffers')?.max_ms}ms
  confidence: high
  suggestions:
  - 帧缓冲交换延迟，可能是 GPU/SF 瓶颈
  - 检查三缓冲是否正常
- condition: binder_blocking_data?.data?.length > 0 && binder_blocking_data.data[0]?.max_block_ms > 5
  severity: critical
  diagnosis: Binder 同步调用阻塞 ${binder_blocking_data.data[0].max_block_ms}ms (${binder_blocking_data.data[0].server_process})
  confidence: high
  suggestions:
  - 将 Binder 调用移到后台线程
  - 使用 oneway Binder 调用
  - 检查服务端是否有性能问题
- condition: binder_blocking_data?.data?.length > 0 && binder_blocking_data.data[0]?.total_block_ms > 2
  severity: warning
  diagnosis: Binder 调用总阻塞 ${binder_blocking_data.data[0].total_block_ms}ms (${binder_blocking_data.data[0].call_count}次)
  confidence: high
  suggestions:
  - 减少帧期间的 Binder 调用次数
  - 考虑批量处理或缓存
- condition: Boolean(throttling_data?.data?.find(t => t.core_type === 'big' && t.throttle_detected === 1 && (t.freq_drop_pct
    || 0) > 20 && (t.max_freq_mhz || 0) > (t.min_freq_mhz || 0)))
  severity: critical
  diagnosis: '检测到 CPU 限频: 大核最低 ${throttling_data.data.find(t => t.core_type === ''big'' && t.throttle_detected === 1)?.min_freq_mhz}MHz（峰值
    ${throttling_data.data.find(t => t.core_type === ''big'' && t.throttle_detected === 1)?.max_freq_mhz}MHz，降幅 ${throttling_data.data.find(t
    => t.core_type === ''big'' && t.throttle_detected === 1)?.freq_drop_pct}%）'
  confidence: high
  suggestions:
  - 设备温度过高触发限频
  - 减少持续高负载任务
  - 检查散热状况
- condition: Boolean(throttling_data?.data?.find(t => t.core_type === 'big' && (t.freq_drop_pct || 0) > 20))
  severity: warning
  diagnosis: 帧期间大核降频 ${throttling_data.data.find(t => t.core_type === 'big')?.freq_drop_pct}%
  confidence: high
  suggestions:
  - CPU 频率不稳定影响性能
  - 检查功耗管理策略
- condition: cluster_load_data?.data?.find(c => c.cluster === '大核簇')?.load_pct > 90
  severity: critical
  diagnosis: 大核簇负载 ${cluster_load_data.data.find(c => c.cluster === '大核簇')?.load_pct}%，接近跑满
  confidence: high
  suggestions:
  - 大核资源严重不足
  - 检查是否有后台密集计算任务
  - 考虑优化或推迟非关键任务
- condition: cluster_load_data?.data?.find(c => c.cluster === '小核簇')?.load_pct > 95
  severity: warning
  diagnosis: 小核簇负载 ${cluster_load_data.data.find(c => c.cluster === '小核簇')?.load_pct}%，几乎跑满
  confidence: high
  suggestions:
  - 系统整体负载很高
  - 后台任务可能挤占资源
- condition: cluster_load_data?.data?.find(c => c.cluster === '大核簇')?.load_pct > 70 && cluster_load_data?.data?.find(c =>
    c.cluster === '小核簇')?.load_pct > 70
  severity: warning
  diagnosis: 'CPU 整体负载高: 大核 ${cluster_load_data.data.find(c => c.cluster === ''大核簇'')?.load_pct}%, 小核 ${cluster_load_data.data.find(c
    => c.cluster === ''小核簇'')?.load_pct}%'
  confidence: high
  suggestions:
  - 系统 CPU 资源紧张
  - 多任务竞争导致调度延迟
- condition: cluster_load_data?.data?.find(c => c.cluster === '大核簇')?.max_single_core_pct > 95
  severity: info
  diagnosis: 大核簇中有核心接近 100% (${cluster_load_data.data.find(c => c.cluster === '大核簇')?.max_single_core_pct}%)
  confidence: medium
  suggestions:
  - 可能有单线程密集任务
  - 检查是否有热点线程
- condition: page_fault_data?.data?.length > 0 && page_fault_data.data[0]?.total_ms > 2
  severity: critical
  diagnosis: ${page_fault_data.data[0].thread_name} 内存操作阻塞 ${page_fault_data.data[0].total_ms}ms (${page_fault_data.data[0].fault_type})
  confidence: high
  suggestions:
  - 触发页面错误或内存回收
  - 预加载可能需要的数据
  - 检查内存压力
- condition: page_fault_data?.data?.find(p => p.fault_type === 'memory_reclaim')?.total_ms > 1
  severity: warning
  diagnosis: 系统内存回收导致阻塞 ${page_fault_data.data.find(p => p.fault_type === 'memory_reclaim')?.total_ms}ms
  confidence: high
  suggestions:
  - 系统内存紧张
  - 检查应用内存使用
- condition: sf_data?.data?.find(s => s.composition_type === 'Composite')?.total_ms > 3
  severity: warning
  diagnosis: SurfaceFlinger 合成耗时 ${sf_data.data.find(s => s.composition_type === 'Composite')?.total_ms}ms
  confidence: medium
  suggestions:
  - 系统合成层可能是瓶颈
  - 检查图层数量和复杂度
- condition: gpu_freq_data?.data?.length > 0 && gpu_freq_data.data[0]?.low_freq_pct > 50
  severity: warning
  diagnosis: GPU 低频运行占比 ${gpu_freq_data.data[0].low_freq_pct}%
  confidence: medium
  suggestions:
  - GPU 未能提升频率
  - 检查 GPU 功耗策略
- condition: vsync_data?.data?.find(v => v.metric === '截止时间')?.value?.includes('超时')
  severity: warning
  diagnosis: '帧未能在 VSync 前完成: ${vsync_data.data.find(v => v.metric === ''截止时间'')?.value}'
  confidence: high
  suggestions:
  - 帧渲染超过 VSync 周期
  - 需要优化帧渲染时间
- condition: pipeline_data?.data?.find(p => p.stage?.includes('主线程'))?.pct > 70
  severity: info
  diagnosis: 主线程占用帧时间 ${pipeline_data.data.find(p => p.stage?.includes('主线程'))?.pct}%
  confidence: high
  suggestions:
  - 主线程是主要瓶颈
  - 检查主线程耗时操作
- condition: pipeline_data?.data?.find(p => p.stage?.includes('RenderThread'))?.pct > 60
  severity: info
  diagnosis: RenderThread 占用帧时间 ${pipeline_data.data.find(p => p.stage?.includes('RenderThread'))?.pct}%
  confidence: high
  suggestions:
  - 渲染是主要瓶颈
  - 检查 GPU 操作和绘制复杂度
- condition: binder_data?.data?.length > 0 && binder_data.data[0]?.dur_ms > 2
  severity: warning
  diagnosis: Binder 调用耗时 ${binder_data.data[0].dur_ms}ms (${binder_data.data[0].interface})
  confidence: high
  suggestions:
  - 检查是否可以异步调用
  - 考虑使用缓存减少调用次数
- condition: quadrant_data?.data?.find(q => q.quadrant?.includes('Q3'))?.percentage > 15
  severity: warning
  diagnosis: 主线程 Runnable 等待 ${quadrant_data.data.find(q => q.quadrant?.includes('Q3'))?.percentage}%
  confidence: high
  suggestions:
  - CPU 资源争抢，检查后台任务
  - 考虑提高线程优先级
- condition: quadrant_data?.data?.find(q => q.quadrant?.includes('MainThread') && q.quadrant?.includes('Q4'))?.percentage
    > 40
  severity: warning
  diagnosis: 主线程休眠/阻塞时间占比 ${quadrant_data.data.find(q => q.quadrant?.includes('MainThread') && q.quadrant?.includes('Q4'))?.percentage}%
  confidence: high
  suggestions:
  - 检查是否有 IO 操作或锁等待
  - 考虑使用异步 IO
- condition: quadrant_data?.data?.find(q => q.quadrant?.includes('MainThread') && q.quadrant?.includes('Q2'))?.percentage
    > 60
  severity: info
  diagnosis: 主线程主要运行在小核 (${quadrant_data.data.find(q => q.quadrant?.includes('MainThread') && q.quadrant?.includes('Q2'))?.percentage}%)
  confidence: medium
  suggestions:
  - 检查系统温控是否限制大核
  - 考虑提高线程优先级
- condition: main_slices?.data?.length > 0 && main_slices.data[0]?.dur_ms > 5
  severity: warning
  diagnosis: 主线程操作 '${main_slices.data[0].name}' 耗时 ${main_slices.data[0].dur_ms}ms
  confidence: high
  suggestions:
  - 考虑将耗时操作移到后台线程
  - 优化该操作的执行效率
- condition: render_slices?.data?.length > 0 && render_slices.data[0]?.dur_ms > 3
  severity: warning
  diagnosis: RenderThread 操作 '${render_slices.data[0].name}' 耗时 ${render_slices.data[0].dur_ms}ms
  confidence: high
  suggestions:
  - 检查是否有复杂的自定义绘制
  - 考虑减少绘制复杂度或使用硬件加速
- condition: freq_data?.data?.find(f => f.core_type === 'big')?.avg_freq_mhz < 1500
  severity: info
  diagnosis: 大核频率偏低 (${freq_data.data?.find(f => f.core_type === 'big')?.avg_freq_mhz || 0}MHz)
  confidence: medium
  suggestions:
  - 系统可能处于省电模式
  - 检查温控策略
- condition: freq_timeline?.data?.filter(f => f.change_direction === 'down' && f.core_type === 'big').length > 2
  severity: info
  diagnosis: 大核频率降频 ${freq_timeline.data?.filter(f => f.change_direction === 'down' && f.core_type === 'big').length || 0}次
  confidence: medium
  suggestions:
  - 可能触发了温控降频
  - 检查系统负载和温度
- condition: ${vsync_missed} >= 3
  severity: critical
  diagnosis: '严重卡顿: SF 跳过 ${vsync_missed} 帧 VSync (约 ${vsync_missed} 个 VSync 周期)'
  confidence: high
  suggestions:
  - 检查此时系统是否有大量后台活动
  - 查看主线程和 RenderThread 的阻塞原因
- condition: ${vsync_missed} >= 1
  severity: warning
  diagnosis: '掉帧: SF 跳过 ${vsync_missed} 帧 VSync'
  confidence: high
  suggestions:
  - 查看上方四象限和耗时操作数据
```
## Output and evidence contract

```yaml
format: structured
```
