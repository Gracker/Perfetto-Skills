GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/modem_network_correlation_summary.skill.yaml
Source SHA-256: 7cca2aaa1525cb329a14c22261e7c4fb8365284a7410d31bb6d9605950895a47
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# Modem Rail 与网络相关性

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: modem_network_correlation_summary
version: '1.0'
type: atomic
category: power
tier: A
```

## Metadata

```yaml
display_name: Modem Rail 与网络相关性
description: 将 modem/cellular/radio rail 能耗与 android.network_packets 按包名/UID/socket_tag 相关联
icon: cell_tower
tags:
- power
- modem
- cellular
- network
- radio
- correlation
- atomic
```

## Prerequisites

```yaml
modules:
- android.power_rails
- android.network_packets
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: top_n
  type: number
  required: false
  default: 20
  description: 返回前 N 个网络来源
```

## Ordered execution

### Modem/网络相关性

- ID: `modem_network_correlation`
- Type: `atomic`
- SQL: [`../sql/modem_network_correlation_summary/modem_network_correlation.sql`](../sql/modem_network_correlation_summary/modem_network_correlation.sql)

```yaml
id: modem_network_correlation
type: atomic
display:
  level: detail
  layer: list
  title: Modem Rail 与蜂窝网络相关性
  columns:
  - name: package_name
    label: 包名
    type: string
  - name: socket_uid
    label: UID
    type: number
  - name: socket_tag
    label: Socket Tag
    type: string
  - name: packet_count
    label: 包数
    type: number
    format: compact
  - name: bytes
    label: 字节
    type: bytes
  - name: cellular_uptime_sec
    label: 估算蜂窝活跃(秒)
    type: number
    format: compact
  - name: modem_energy_mwh
    label: Modem rail 能耗(mWh)
    type: number
    format: compact
  - name: confidence
    label: 置信度
    type: string
```
## Output and evidence contract

```yaml
format: structured
```
