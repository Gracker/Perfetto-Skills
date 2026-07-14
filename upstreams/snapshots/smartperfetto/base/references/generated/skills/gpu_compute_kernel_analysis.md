GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/gpu_compute_kernel_analysis.skill.yaml
Source SHA-256: 04ce0fdb105d89c591b8d24656540615492754eb847da9f8bec211de2a39e9df
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# GPU Compute Kernel Analysis

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_compute_kernel_analysis
version: '1.0'
type: composite
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU Compute Kernel Analysis
description: Vendor-neutral GPU compute kernel timing and producer-provided launch configuration evidence
icon: memory
tags:
- gpu
- compute
- kernel
- launch
- workgroup
- upstream
```

## Triggers

```yaml
keywords:
  zh:
  - GPU compute
  - 计算内核
  - workgroup
  - grid size
  - 启动配置
  en:
  - gpu compute
  - compute kernel
  - workgroup
  - grid size
  - launch configuration
patterns:
- .*(GPU|gpu).*(compute|kernel|workgroup|grid).*
- .*(计算内核|启动配置|工作组).*
```

## Prerequisites

```yaml
modules:
- prelude.after_eof.events
required_tables:
- gpu_slice
- gpu_track
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: Optional inclusive start timestamp in ns
- name: end_ts
  type: timestamp
  required: false
  description: Optional exclusive end timestamp in ns
- name: ugpu
  type: integer
  required: false
  description: Optional host-unique GPU id
- name: max_rows
  type: integer
  required: false
  default: 50
  description: Maximum kernel or launch rows, clamped to 200
```

## Ordered execution

### GPU compute data availability

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/gpu_compute_kernel_analysis/data_check.sql`](../sql/gpu_compute_kernel_analysis/data_check.sql)

```yaml
id: data_check
type: atomic
display:
  level: hidden
save_as: data_check
```
### GPU compute kernel timing

- ID: `kernel_summary`
- Type: `atomic`
- SQL: [`../sql/gpu_compute_kernel_analysis/kernel_summary.sql`](../sql/gpu_compute_kernel_analysis/kernel_summary.sql)

```yaml
id: kernel_summary
type: atomic
condition: data_check.data[0]?.compute_rows > 0
display:
  level: key
  layer: list
  title: GPU Compute Kernels
  columns:
  - name: launch_id
    label: Launch
    type: number
  - name: kernel
    label: Kernel
    type: string
  - name: ugpu
    label: GPU
    type: number
  - name: ts
    label: Timestamp
    type: timestamp
    unit: ns
  - name: dur_ns
    label: Duration
    type: duration
    unit: ns
  - name: compute_time_pct
    label: Compute Time Share
    type: percentage
    format: percentage
save_as: kernel_summary
```
### Producer-provided compute launch configuration

- ID: `launch_configuration`
- Type: `atomic`
- SQL: [`../sql/gpu_compute_kernel_analysis/launch_configuration.sql`](../sql/gpu_compute_kernel_analysis/launch_configuration.sql)

```yaml
id: launch_configuration
type: atomic
optional: true
condition: data_check.data[0]?.launch_arg_rows > 0
display:
  level: detail
  layer: list
  title: GPU Compute Launch Configuration
  columns:
  - name: launch_id
    label: Launch
    type: number
  - name: kernel
    label: Kernel
    type: string
  - name: grid_x
    label: Grid X
    type: number
  - name: grid_y
    label: Grid Y
    type: number
  - name: grid_z
    label: Grid Z
    type: number
  - name: workgroup_x
    label: Workgroup X
    type: number
  - name: workgroup_y
    label: Workgroup Y
    type: number
  - name: workgroup_z
    label: Workgroup Z
    type: number
  - name: workgroup_threads
    label: Threads / Workgroup
    type: number
  - name: total_threads
    label: Total Threads
    type: number
  - name: registers_per_thread
    label: Registers / Thread
    type: number
  - name: shared_mem_static_bytes
    label: Static Shared Memory
    type: bytes
  - name: shared_mem_dynamic_bytes
    label: Dynamic Shared Memory
    type: bytes
  - name: barriers_per_block
    label: Barriers / Block
    type: number
  - name: waves_per_multiprocessor
    label: Waves / Multiprocessor
    type: number
save_as: launch_configuration
```
### No GPU compute kernels

- ID: `no_compute_contract`
- Type: `atomic`
- SQL: [`../sql/gpu_compute_kernel_analysis/no_compute_contract.sql`](../sql/gpu_compute_kernel_analysis/no_compute_contract.sql)

```yaml
id: no_compute_contract
type: atomic
optional: true
condition: data_check.data[0]?.compute_rows === 0
display:
  level: summary
  layer: overview
  title: GPU Compute Availability
  columns:
  - name: status
    label: Status
    type: string
  - name: limitation
    label: Limitation
    type: string
save_as: no_compute_contract
```
### Compute launch arguments unavailable

- ID: `missing_launch_args_contract`
- Type: `atomic`
- SQL: [`../sql/gpu_compute_kernel_analysis/missing_launch_args_contract.sql`](../sql/gpu_compute_kernel_analysis/missing_launch_args_contract.sql)

```yaml
id: missing_launch_args_contract
type: atomic
optional: true
condition: data_check.data[0]?.compute_rows > 0 && data_check.data[0]?.launch_arg_rows === 0
display:
  level: summary
  layer: overview
  title: GPU Compute Launch Arguments
  columns:
  - name: status
    label: Status
    type: string
  - name: limitation
    label: Limitation
    type: string
save_as: missing_launch_args_contract
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: kernel_summary
  description: Positive-duration vendor-neutral GPU compute kernel timing evidence
- name: launch_configuration
  description: Producer-provided grid, workgroup, register, shared-memory, barrier, and wave arguments
- name: limitation_contract
  description: Explicit distinction between absent kernels and omitted launch metadata
```
