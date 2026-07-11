GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/irq_analysis.skill.yaml
Source SHA-256: 2790ff697fe7ae14da02b54deb78e2d1b46dd8d3cbebb27599a1e20f8ca5a2cf
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# IRQ 中断分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: irq_analysis
version: '3.0'
type: composite
tier: S
```

## Metadata

```yaml
display_name: IRQ 中断分析
description: 分析硬件中断和软中断对系统性能的影响
icon: bolt
tags:
- irq
- interrupt
- kernel
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 中断
  - 硬中断
  - 软中断
  - IRQ
  - 中断延迟
  - 中断负载
  en:
  - interrupt
  - hard irq
  - soft irq
  - IRQ
  - interrupt latency
  - irq load
patterns:
- .*中断.*
- .*[Ii][Rr][Qq].*
- .*interrupt.*
- .*softirq.*
```

## Prerequisites

```yaml
required_tables:
- slice
modules:
- linux.cpu.irq
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选，用于关联分析）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: hard_irq_long_threshold_us
  type: number
  required: false
  default: 1000
  description: 硬中断长耗时阈值（微秒，默认 1000us=1ms）
- name: soft_irq_long_threshold_us
  type: number
  required: false
  default: 10000
  description: 软中断长耗时阈值（微秒，默认 10000us=10ms）
- name: irq_rate_heavy_threshold
  type: number
  required: false
  default: 10000
  description: 中断频率重负载阈值（次/秒）
- name: irq_dur_heavy_threshold_ms
  type: number
  required: false
  default: 50
  description: 中断耗时重负载阈值（ms/秒）
```

## Ordered execution

### IRQ 数据检测

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/data_check.sql`](../sql/irq_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
display: false
save_as: data_check
```
### 中断概览

- ID: `irq_overview`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/irq_overview.sql`](../sql/irq_analysis/irq_overview.sql)

```yaml
id: irq_overview
type: atomic
synthesize:
  role: overview
  fields:
  - key: irq_type
    label: 中断类型
  - key: irq_count
    label: 中断次数
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  - key: max_dur_us
    label: 最大耗时
    format: '{{value}} us'
  insights:
  - condition: irq_type === 'Hard IRQ' && max_dur_us > 1000
    template: 硬中断最大耗时 {{max_dur_us}}us (>1ms)，可能影响实时性
  - condition: irq_type === 'Soft IRQ' && max_dur_us > 10000
    template: 软中断最大耗时 {{max_dur_us}}us (>10ms)，可能导致调度延迟
  - condition: irq_count > 100000
    template: '{{irq_type}} 次数过多 ({{irq_count}})，中断负载较重'
display:
  level: summary
  layer: overview
  title: 硬中断 vs 软中断概览
  columns:
  - name: irq_type
    label: 中断类型
    type: string
  - name: irq_count
    label: 中断次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_us
    label: 平均耗时(us)
    type: number
    format: compact
  - name: max_dur_us
    label: 最大耗时(us)
    type: number
    format: compact
save_as: irq_overview
optional: true
condition: data_check.data[0]?.has_irq_data === 1
```
### 顶级 IRQ 源

- ID: `top_irq_sources`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/top_irq_sources.sql`](../sql/irq_analysis/top_irq_sources.sql)

```yaml
id: top_irq_sources
type: atomic
synthesize:
  role: list
  groupBy:
  - field: irq_type
    title: 按中断类型分布
  fields:
  - key: irq_name
    label: 中断名称
  - key: irq_count
    label: 次数
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
display:
  level: key
  layer: overview
  title: 顶级中断源排行
  columns:
  - name: irq_name
    label: 中断名
    type: string
  - name: irq_type
    label: 类型
    type: string
  - name: irq_count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_us
    label: 平均(us)
    type: number
    format: compact
  - name: max_dur_us
    label: 最大(us)
    type: number
    format: compact
  - name: time_pct
    label: 占比(%)
    type: percentage
    format: percentage
save_as: top_irq_sources
optional: true
condition: data_check.data[0]?.has_irq_data === 1
```
### 硬中断明细

- ID: `hard_irq_detail`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/hard_irq_detail.sql`](../sql/irq_analysis/hard_irq_detail.sql)

```yaml
id: hard_irq_detail
type: atomic
display:
  level: key
  layer: list
  title: 硬中断详情
  columns:
  - name: irq_name
    label: 中断名
    type: string
  - name: irq_count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_us
    label: 平均(us)
    type: number
    format: compact
  - name: max_dur_us
    label: 最大(us)
    type: number
    format: compact
  - name: severity
    label: 严重程度
    type: string
save_as: hard_irq_detail
optional: true
condition: data_check.data[0]?.has_irq_data === 1
```
### 软中断明细

- ID: `soft_irq_detail`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/soft_irq_detail.sql`](../sql/irq_analysis/soft_irq_detail.sql)

```yaml
id: soft_irq_detail
type: atomic
display:
  level: key
  layer: list
  title: 软中断详情
  columns:
  - name: irq_name
    label: 中断名
    type: string
  - name: irq_count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_us
    label: 平均(us)
    type: number
    format: compact
  - name: max_dur_us
    label: 最大(us)
    type: number
    format: compact
  - name: severity
    label: 严重程度
    type: string
save_as: soft_irq_detail
optional: true
condition: data_check.data[0]?.has_irq_data === 1
```
### 长耗时中断事件

- ID: `long_irq_events`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/long_irq_events.sql`](../sql/irq_analysis/long_irq_events.sql)

```yaml
id: long_irq_events
type: atomic
synthesize:
  role: list
  groupBy:
  - field: irq_type
    title: 按中断类型分布
  - field: severity
    title: 按严重程度分布
  fields:
  - key: irq_name
    label: 中断名
  - key: dur_us
    label: 耗时
    format: '{{value}} us'
  - key: severity
    label: 严重程度
display:
  level: key
  layer: list
  title: 长耗时中断事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: irq_name
    label: 中断名
    type: string
  - name: irq_type
    label: 类型
    type: string
  - name: dur_us
    label: 耗时(us)
    type: number
    format: compact
  - name: cpu
    label: CPU
    type: number
  - name: severity
    label: 严重程度
    type: string
save_as: long_irq_events
optional: true
condition: data_check.data[0]?.has_irq_data === 1
```
### 中断时间分布

- ID: `irq_timeline`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/irq_timeline.sql`](../sql/irq_analysis/irq_timeline.sql)

```yaml
id: irq_timeline
type: atomic
display:
  level: detail
  layer: list
  title: 中断频率时间线（每秒）
  columns:
  - name: second
    label: 时间(s)
    type: number
  - name: hard_irq_count
    label: 硬中断数
    type: number
    format: compact
  - name: soft_irq_count
    label: 软中断数
    type: number
    format: compact
  - name: hard_irq_dur_ms
    label: 硬中断耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: soft_irq_dur_ms
    label: 软中断耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: total_irq_count
    label: 总中断数
    type: number
    format: compact
save_as: irq_timeline
optional: true
condition: data_check.data[0]?.has_irq_data === 1
```
### 根因分类

- ID: `root_cause_classification`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/root_cause_classification.sql`](../sql/irq_analysis/root_cause_classification.sql)

```yaml
id: root_cause_classification
type: atomic
synthesize:
  role: conclusion
  fields:
  - key: classification
    label: 分类
  - key: total_irq_count
    label: 总中断数
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  insights:
  - condition: classification === 'IRQ_LATENCY'
    template: 存在异常长耗时中断，可能影响实时性
  - condition: classification === 'IRQ_HEAVY'
    template: 中断负载较重 ({{total_irq_count}} 次)，可能影响 CPU 可用时间
display:
  level: summary
  layer: overview
  title: 中断根因分类
  columns:
  - name: classification
    label: 分类
    type: string
  - name: total_irq_count
    label: 总中断数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: long_hard_irq_count
    label: 长硬中断数
    type: number
  - name: long_soft_irq_count
    label: 长软中断数
    type: number
  - name: description
    label: 描述
    type: string
save_as: root_cause
condition: data_check.data[0]?.has_irq_data === 1
```
### 中断诊断

- ID: `irq_diagnosis`
- Type: `diagnostic`

```yaml
id: irq_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  - key: confidence
    label: 置信度
  insights:
  - template: 中断诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- irq_overview
- top_irq_sources
- long_irq_events
- root_cause
rules:
- condition: root_cause.data[0]?.classification === 'IRQ_LATENCY'
  severity: critical
  diagnosis: 检测到异常长耗时中断 (硬中断 ${root_cause.data[0].long_hard_irq_count} 次 >1ms，软中断 ${root_cause.data[0].long_soft_irq_count}
    次 >10ms)
  confidence: high
  suggestions:
  - 检查长耗时硬中断对应的设备驱动
  - 分析软中断堆积原因 (NET_RX/TIMER 等)
  - 考虑将中断绑定到特定 CPU 核心避免影响关键任务
- condition: root_cause.data[0]?.classification === 'IRQ_HEAVY'
  severity: warning
  diagnosis: 中断负载较重 (总计 ${root_cause.data[0].total_irq_count} 次，耗时 ${root_cause.data[0].total_dur_ms}ms)
  confidence: high
  suggestions:
  - 检查高频中断源，评估是否可以合并或降频
  - 使用 IRQ affinity 分散中断负载
  - 检查网络和存储 IO 是否导致过多中断
- condition: root_cause.data[0]?.classification === 'IRQ_NORMAL'
  severity: info
  diagnosis: 中断负载正常，无异常
  confidence: high
  suggestions:
  - 当前中断状态良好
```
### 无 IRQ 数据

- ID: `no_data_fallback`
- Type: `atomic`
- SQL: [`../sql/irq_analysis/no_data_fallback.sql`](../sql/irq_analysis/no_data_fallback.sql)

```yaml
id: no_data_fallback
type: atomic
display:
  level: summary
  layer: overview
  title: IRQ 数据不可用
  columns:
  - name: message
    label: 说明
    type: string
save_as: no_data_fallback
condition: data_check.data[0]?.has_irq_data !== 1
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- irq_overview
- top_irq_sources
- root_cause_classification
```
