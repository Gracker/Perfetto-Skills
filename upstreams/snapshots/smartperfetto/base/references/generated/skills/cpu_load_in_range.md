GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
Source SHA-256: b24f5a2e47a5f0d7ae34fcfc86c1a7f58e53b09f13f6b5e6e36b5a998da2053c
Source commit: bc007586871a720aed82537913617c64fb95a459
# CPU 负载区间分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_load_in_range
version: '2.0'
type: composite
category: hardware
tier: B
```

## Metadata

```yaml
display_name: CPU 负载区间分析
description: 分析指定时间范围内各 CPU 核心的负载情况
icon: bar_chart
tags:
- cpu
- load
- usage
- composite
```

## Prerequisites

```yaml
required_tables:
- sched_slice
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
```

## Ordered execution

### CPU 利用率

- ID: `cpu_utilization`
- Type: `atomic`
- SQL: [`../sql/cpu_load_in_range/cpu_utilization.sql`](../sql/cpu_load_in_range/cpu_utilization.sql)

```yaml
id: cpu_utilization
type: atomic
display:
  level: detail
  title: CPU 利用率
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
save_as: utilization
```
### 运行队列深度

- ID: `runqueue_depth`
- Type: `atomic`
- SQL: [`../sql/cpu_load_in_range/runqueue_depth.sql`](../sql/cpu_load_in_range/runqueue_depth.sql)

```yaml
id: runqueue_depth
type: atomic
display:
  level: detail
  title: 运行队列
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
save_as: runqueue
optional: true
```
### 线程迁移

- ID: `thread_migrations`
- Type: `atomic`
- SQL: [`../sql/cpu_load_in_range/thread_migrations.sql`](../sql/cpu_load_in_range/thread_migrations.sql)

```yaml
id: thread_migrations
type: atomic
display:
  level: summary
  title: 线程迁移
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
save_as: migrations
```
## Output and evidence contract

```yaml
format: structured
```
