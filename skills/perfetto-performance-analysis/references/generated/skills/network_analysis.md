GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/network_analysis.skill.yaml
Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# 网络活动分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: network_analysis
version: '3.0'
type: composite
category: network
tier: S
```

## Metadata

```yaml
display_name: 网络活动分析
description: 分析网络包收发活动、协议分布和功耗影响
icon: wifi
tags:
- network
- packet
- traffic
- power
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - 网络
  - 流量
  - 数据包
  - 网络唤醒
  - 数据传输
  - WiFi
  - 移动网络
  en:
  - network
  - traffic
  - packet
  - network wakeup
  - data transfer
  - wifi
  - cellular
patterns:
- .*网络.*
- .*network.*
- .*流量.*
- .*(WiFi|wifi|4G|5G|cellular).*
- .*(TCP|UDP|packet|数据包).*
```

## Prerequisites

```yaml
optional_tables:
- track
modules:
- android.network_packets
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名（可选，留空分析所有流量）
- name: interface
  type: string
  required: false
  description: 网络接口过滤（wlan0, rmnet_data0 等）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
- name: heavy_traffic_critical_mb
  type: number
  required: false
  default: 100
  description: 大流量严重阈值（MB）
- name: heavy_traffic_warning_mb
  type: number
  required: false
  default: 10
  description: 大流量警告阈值（MB）
- name: frequent_active_periods
  type: number
  required: false
  default: 20
  description: 频繁网络活跃周期阈值（次数）
```

## Ordered execution

### 检查网络数据

- ID: `check_network_data`
- Type: `atomic`
- SQL: [`../sql/network_analysis/check_network_data.sql`](../sql/network_analysis/check_network_data.sql)

```yaml
id: check_network_data
type: atomic
display: false
optional: true
save_as: network_check
```
### 检查网络 Slice 数据

- ID: `check_network_slices`
- Type: `atomic`
- SQL: [`../sql/network_analysis/check_network_slices.sql`](../sql/network_analysis/check_network_slices.sql)

```yaml
id: check_network_slices
type: atomic
display: false
save_as: network_slice_check
condition: network_check.data[0]?.status === 'unavailable'
```
### 证据范围说明

- ID: `evidence_scope`
- Type: `atomic`
- SQL: [`../sql/network_analysis/evidence_scope.sql`](../sql/network_analysis/evidence_scope.sql)

```yaml
id: evidence_scope
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: evidence_class
    label: 证据类型
  - key: supported_claims
    label: 可支持结论
  - key: unsupported_claims
    label: 不可直接证明
  insights:
  - template: '{{supported_claims}}；{{unsupported_claims}}'
display:
  level: summary
  layer: overview
  title: 网络证据范围
  columns:
  - name: evidence_class
    label: 证据类型
    type: string
  - name: supported_claims
    label: 可支持结论
    type: string
  - name: unsupported_claims
    label: 不可直接证明
    type: string
  - name: required_complement
    label: 补证方向
    type: string
save_as: evidence_scope
condition: network_check.data[0]?.status === 'available'
```
### 网络流量概览

- ID: `network_overview`
- Type: `atomic`
- SQL: [`../sql/network_analysis/network_overview.sql`](../sql/network_analysis/network_overview.sql)

```yaml
id: network_overview
type: atomic
optional: true
synthesize:
  role: overview
  fields:
  - key: total_events
    label: 总事件数
  - key: total_packets
    label: 总数据包
  - key: total_mb
    label: 总流量
    format: '{{value}} MB'
  - key: rating
    label: 评级
  insights:
  - condition: total_mb > 100
    template: 网络流量较大 ({{total_mb}} MB)，可能影响功耗
  - condition: total_events > 1000
    template: 网络事件频繁 ({{total_events}} 次)，检查是否可批量化
display:
  level: key
  layer: overview
  title: 网络流量概览
  columns:
  - name: total_events
    label: 总事件数
    type: number
    format: compact
  - name: total_packets
    label: 总数据包
    type: number
    format: compact
  - name: total_kb
    label: 总流量 (KB)
    type: number
    format: compact
  - name: total_mb
    label: 总流量 (MB)
    type: number
    format: compact
  - name: tx_packets
    label: 发送包数
    type: number
    format: compact
  - name: rx_packets
    label: 接收包数
    type: number
    format: compact
  - name: tx_kb
    label: 发送 (KB)
    type: number
    format: compact
  - name: rx_kb
    label: 接收 (KB)
    type: number
    format: compact
  - name: rating
    label: 评级
    type: string
save_as: network_overview
condition: network_check.data[0]?.status === 'available'
```
### 按接口流量分布

- ID: `traffic_by_interface`
- Type: `atomic`
- SQL: [`../sql/network_analysis/traffic_by_interface.sql`](../sql/network_analysis/traffic_by_interface.sql)

```yaml
id: traffic_by_interface
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: iface
    title: 按网络接口分布
  fields:
  - key: iface
    label: 接口
  - key: total_kb
    label: 流量
    format: '{{value}} KB'
display:
  level: key
  layer: overview
  title: 按接口流量分布
  columns:
  - name: iface
    label: 网络接口
    type: string
  - name: direction
    label: 方向
    type: string
  - name: event_count
    label: 事件数
    type: number
    format: compact
  - name: total_packets
    label: 数据包数
    type: number
    format: compact
  - name: total_kb
    label: 流量 (KB)
    type: number
    format: compact
save_as: traffic_by_interface
condition: network_check.data[0]?.status === 'available'
```
### 应用流量排行

- ID: `app_traffic_ranking`
- Type: `atomic`
- SQL: [`../sql/network_analysis/app_traffic_ranking.sql`](../sql/network_analysis/app_traffic_ranking.sql)

```yaml
id: app_traffic_ranking
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: package_name
    title: 按应用分布
  fields:
  - key: package_name
    label: 应用包名
  - key: total_kb
    label: 流量
    format: '{{value}} KB'
display:
  level: key
  layer: list
  title: 应用流量排行
  columns:
  - name: package_name
    label: 应用包名
    type: string
  - name: direction
    label: 方向
    type: string
  - name: event_count
    label: 事件数
    type: number
    format: compact
  - name: total_packets
    label: 数据包数
    type: number
    format: compact
  - name: total_kb
    label: 流量 (KB)
    type: number
    format: compact
save_as: app_traffic_ranking
condition: network_check.data[0]?.status === 'available'
```
### 传输协议分布

- ID: `transport_distribution`
- Type: `atomic`
- SQL: [`../sql/network_analysis/transport_distribution.sql`](../sql/network_analysis/transport_distribution.sql)

```yaml
id: transport_distribution
type: atomic
optional: true
synthesize:
  role: list
  groupBy:
  - field: packet_transport
    title: 按传输协议分布
  fields:
  - key: packet_transport
    label: 协议
  - key: total_kb
    label: 流量
    format: '{{value}} KB'
display:
  level: key
  layer: list
  title: 传输协议分布
  columns:
  - name: packet_transport
    label: 传输协议
    type: string
  - name: event_count
    label: 事件数
    type: number
    format: compact
  - name: total_packets
    label: 数据包数
    type: number
    format: compact
  - name: total_kb
    label: 流量 (KB)
    type: number
    format: compact
save_as: transport_distribution
condition: network_check.data[0]?.status === 'available'
```
### 端口使用分析

- ID: `port_analysis`
- Type: `atomic`
- SQL: [`../sql/network_analysis/port_analysis.sql`](../sql/network_analysis/port_analysis.sql)

```yaml
id: port_analysis
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 远程端口使用分析
  columns:
  - name: remote_port
    label: 远程端口
    type: number
  - name: service
    label: 服务类型
    type: string
  - name: event_count
    label: 事件数
    type: number
    format: compact
  - name: total_packets
    label: 数据包数
    type: number
    format: compact
  - name: total_kb
    label: 流量 (KB)
    type: number
    format: compact
save_as: port_analysis
condition: network_check.data[0]?.status === 'available'
```
### 流量时间分布

- ID: `traffic_timeline`
- Type: `atomic`
- SQL: [`../sql/network_analysis/traffic_timeline.sql`](../sql/network_analysis/traffic_timeline.sql)

```yaml
id: traffic_timeline
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 流量时间分布（每秒）
  columns:
  - name: time_sec
    label: 时间 (秒)
    type: number
  - name: packets_per_sec
    label: 包数/秒
    type: number
    format: compact
  - name: kb_per_sec
    label: 流量/秒 (KB)
    type: number
    format: compact
  - name: tx_kb
    label: 发送 (KB)
    type: number
    format: compact
  - name: rx_kb
    label: 接收 (KB)
    type: number
    format: compact
save_as: traffic_timeline
condition: network_check.data[0]?.status === 'available'
```
### 大流量传输事件

- ID: `large_transfers`
- Type: `atomic`
- SQL: [`../sql/network_analysis/large_transfers.sql`](../sql/network_analysis/large_transfers.sql)

```yaml
id: large_transfers
type: atomic
optional: true
display:
  level: key
  layer: list
  title: 大流量传输事件（Top 20）
  columns:
  - name: event_ts
    label: 时间
    type: timestamp
    clickAction: navigate_timeline
  - name: package_name
    label: 应用
    type: string
  - name: iface
    label: 接口
    type: string
  - name: direction
    label: 方向
    type: string
  - name: packet_transport
    label: 协议
    type: string
  - name: packet_count
    label: 包数
    type: number
  - name: kb
    label: 大小 (KB)
    type: number
    format: compact
save_as: large_transfers
condition: network_check.data[0]?.status === 'available'
```
### 网络功耗影响

- ID: `network_power_cost`
- Type: `atomic`
- SQL: [`../sql/network_analysis/network_power_cost.sql`](../sql/network_analysis/network_power_cost.sql)

```yaml
id: network_power_cost
type: atomic
optional: true
synthesize:
  role: list
  fields:
  - key: iface
    label: 接口
  - key: total_active_sec
    label: 活跃时间
    format: '{{value}} 秒'
  - key: active_periods
    label: 活跃周期数
display:
  level: key
  layer: list
  title: 网络功耗影响（10 秒空闲超时模型）
  columns:
  - name: iface
    label: 网络接口
    type: string
  - name: active_periods
    label: 活跃周期数
    type: number
    format: compact
  - name: total_active_sec
    label: 总活跃时间 (秒)
    type: number
    format: compact
  - name: avg_active_sec
    label: 平均活跃时长 (秒)
    type: number
    format: compact
  - name: total_packets
    label: 总包数
    type: number
    format: compact
  - name: total_mb
    label: 总流量 (MB)
    type: number
    format: compact
save_as: network_power_cost
condition: network_check.data[0]?.status === 'available'
```
### 网络相关 Slice 概览

- ID: `network_slice_overview`
- Type: `atomic`
- SQL: [`../sql/network_analysis/network_slice_overview.sql`](../sql/network_analysis/network_slice_overview.sql)

```yaml
id: network_slice_overview
type: atomic
display:
  level: key
  layer: overview
  title: 网络相关 Slice（无 android_network_packets 数据时）
  columns:
  - name: slice_name
    label: Slice 名称
    type: string
  - name: count
    label: 出现次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
    unit: ms
save_as: network_slice_overview
condition: network_check.data[0]?.status === 'unavailable' && network_slice_check.data[0]?.status === 'available'
```
### 网络诊断

- ID: `network_diagnosis`
- Type: `diagnostic`

```yaml
id: network_diagnosis
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
  - template: 网络诊断：{{diagnosis}}
display:
  level: key
  layer: overview
  title: 问题诊断
inputs:
- network_overview
- app_traffic_ranking
- transport_distribution
- large_transfers
- network_power_cost
rules:
- condition: network_overview.data[0]?.total_mb > ${heavy_traffic_critical_mb|100}
  severity: critical
  diagnosis: NETWORK_HEAVY - 网络流量过大 (${network_overview.data[0].total_mb} MB)
  confidence: high
  suggestions:
  - 检查是否有不必要的大文件下载
  - 考虑使用压缩传输和增量更新
  - 检查图片/视频资源是否过大
- condition: network_overview.data[0]?.total_mb > ${heavy_traffic_warning_mb|10}
  severity: warning
  diagnosis: NETWORK_HEAVY - 网络流量较大 (${network_overview.data[0].total_mb} MB)
  confidence: medium
  suggestions:
  - 检查流量来源应用
  - 考虑优化资源加载策略
- condition: network_power_cost.data[0]?.active_periods > network_overview.data[0]?.total_mb * 10 && network_power_cost.data[0]?.active_periods
    > ${frequent_active_periods|20}
  severity: warning
  diagnosis: NETWORK_LATENCY - 频繁小量网络传输，功耗影响大（${network_power_cost.data[0].active_periods} 个活跃周期）
  confidence: medium
  suggestions:
  - 批量合并网络请求以减少唤醒次数
  - 使用 JobScheduler 或 WorkManager 延迟非紧急请求
  - 检查后台定时同步频率
- condition: port_analysis.data.find(p => p.service === 'DNS')?.event_count > 100
  severity: warning
  diagnosis: NETWORK_DNS_PACKET_ACTIVITY - 远程端口 53 包活动频繁；当前 packet trace 不能直接证明 DNS 阶段耗时或请求延迟
  confidence: low
  suggestions:
  - 结合 OkHttp/Cronet DNS 阶段埋点或接入层 request_id 证据确认是否存在 DNS 延迟
  - 若确认重复解析，再检查 DNS 缓存、预解析和连接复用策略
- condition: network_overview.data[0]?.total_mb <= ${heavy_traffic_warning_mb|10}
  severity: info
  diagnosis: NETWORK_NORMAL - 网络流量正常
  confidence: high
  suggestions:
  - 网络使用在正常范围内
```
### Fallback 诊断

- ID: `fallback_diagnosis`
- Type: `diagnostic`

```yaml
id: fallback_diagnosis
type: diagnostic
synthesize:
  role: conclusion
  fields:
  - key: diagnosis
    label: 诊断结论
  - key: severity
    label: 严重程度
  insights:
  - template: '{{diagnosis}}'
display:
  level: key
  layer: overview
  title: 数据可用性诊断
inputs:
- network_check
- network_slice_check
rules:
- condition: network_check.data[0]?.status === 'unavailable' && (!network_slice_check.data || network_slice_check.data[0]?.status
    === 'unavailable')
  severity: info
  diagnosis: 未检测到网络数据。Trace 中未包含 android.network_packets 模块数据，也未发现网络相关 Slice。如需分析网络问题，请在录制 Trace 时启用 net 数据源。
  confidence: high
  suggestions:
  - 录制 Trace 时启用 android.network_packets
  - 确保已安装 net hook
condition: network_check.data[0]?.status === 'unavailable'
```
