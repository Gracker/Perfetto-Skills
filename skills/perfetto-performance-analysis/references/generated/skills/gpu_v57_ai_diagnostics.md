GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# GPU v57 AI Diagnostics

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_v57_ai_diagnostics
version: '1.0'
type: composite
category: gpu
tier: B
```

## Metadata

```yaml
display_name: GPU v57 AI Diagnostics
description: Translate Perfetto v57 GPU Agent Skill SQL into deterministic inventory, occupancy, frequency, ramp, and throttle
  evidence
icon: memory
tags:
- gpu
- occupancy
- dvfs
- throttle
- upstream_v57
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - v57 GPU
  - Perfetto AI GPU
  - GPU occupancy
  - GPU DVFS
  - GPU throttle
  - GPU idle
  en:
  - v57 gpu
  - perfetto ai gpu
  - gpu occupancy
  - gpu dvfs
  - gpu throttle
  - gpu idle
patterns:
- .*(v57|Perfetto AI).*[Gg][Pp][Uu].*
- .*[Gg][Pp][Uu].*(occupancy|DVFS|throttle|idle).*
```

## Prerequisites

```yaml
modules:
- counters.intervals
- intervals.overlap
- intervals.intersect
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: Start timestamp in ns
- name: end_ts
  type: timestamp
  required: false
  description: End timestamp in ns
- name: ugpu
  type: integer
  required: false
  description: Optional host-unique GPU id
- name: target_freq_ratio
  type: number
  required: false
  default: 0.9
  description: Target clock ratio relative to observed fmax
- name: min_throttle_ns
  type: integer
  required: false
  default: 1000
  description: Minimum sustained throttle interval in ns
- name: max_rows
  type: integer
  required: false
  default: 20
  description: Maximum rows for event-style tables
```

## Ordered execution

### GPU v57 data availability

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/data_check.sql`](../sql/gpu_v57_ai_diagnostics/data_check.sql)

```yaml
id: data_check
type: atomic
display:
  level: hidden
save_as: data_check
```
### GPU inventory

- ID: `gpu_inventory`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/gpu_inventory.sql`](../sql/gpu_v57_ai_diagnostics/gpu_inventory.sql)

```yaml
id: gpu_inventory
type: atomic
optional: true
condition: data_check.data[0]?.gpu_rows > 0 && data_check.data[0]?.has_gpu_machine_id === 1 && data_check.data[0]?.has_gpu_architecture
  === 1
display:
  level: summary
  layer: list
  title: GPU Inventory
  columns:
  - name: machine_id
    label: Machine
    type: number
  - name: is_host
    label: Host
    type: boolean
  - name: ugpu
    label: UGPU
    type: number
  - name: gpu_index
    label: Index
    type: number
  - name: vendor
    label: Vendor
    type: string
  - name: name
    label: Name
    type: string
  - name: model
    label: Model
    type: string
  - name: architecture
    label: Architecture
    type: string
  - name: uuid
    label: UUID
    type: string
  - name: pci_bdf
    label: PCI
    type: string
save_as: gpu_inventory
```
### GPU timeline occupancy

- ID: `timeline_occupancy`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/timeline_occupancy.sql`](../sql/gpu_v57_ai_diagnostics/timeline_occupancy.sql)

```yaml
id: timeline_occupancy
type: atomic
optional: true
condition: data_check.data[0]?.gpu_activity_rows > 0 && data_check.data[0]?.has_gpu_track_dimensions === 1
display:
  level: summary
  layer: overview
  title: GPU Timeline Occupancy
  columns:
  - name: gpu
    label: GPU
    type: number
  - name: gpu_name
    label: Name
    type: string
  - name: activities
    label: Activities
    type: number
  - name: trace_wall_ns
    label: Trace(ns)
    type: duration
    unit: ns
  - name: active_span_ns
    label: Active Span(ns)
    type: duration
    unit: ns
  - name: gpu_busy_ns
    label: Busy(ns)
    type: duration
    unit: ns
  - name: busy_pct_of_active
    label: Busy/Active
    type: percentage
    format: percentage
  - name: busy_pct_of_trace
    label: Busy/Trace
    type: percentage
    format: percentage
save_as: timeline_occupancy
```
### Largest GPU idle gaps

- ID: `idle_gaps`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/idle_gaps.sql`](../sql/gpu_v57_ai_diagnostics/idle_gaps.sql)

```yaml
id: idle_gaps
type: atomic
optional: true
condition: timeline_occupancy.data?.length > 0
display:
  level: detail
  layer: list
  title: Largest GPU Idle Gaps
  columns:
  - name: gpu
    label: GPU
    type: number
  - name: gpu_name
    label: Name
    type: string
  - name: gap_start_rel_ns
    label: Start(ns)
    type: duration
    unit: ns
  - name: gap_dur_ns
    label: Gap(ns)
    type: duration
    unit: ns
save_as: idle_gaps
```
### GPU frequency residency while busy

- ID: `frequency_residency`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/frequency_residency.sql`](../sql/gpu_v57_ai_diagnostics/frequency_residency.sql)

```yaml
id: frequency_residency
type: atomic
optional: true
condition: data_check.data[0]?.gpufreq_tracks > 0 && data_check.data[0]?.has_gpu_counter_ugpu === 1 && timeline_occupancy.data?.length
  > 0
display:
  level: summary
  layer: overview
  title: GPU Busy Frequency Residency
  columns:
  - name: gpu
    label: GPU
    type: number
  - name: gpu_name
    label: Name
    type: string
  - name: active_span_ns
    label: Active Span(ns)
    type: duration
    unit: ns
  - name: gpu_busy_ns
    label: Busy(ns)
    type: duration
    unit: ns
  - name: busy_pct_of_active
    label: Busy/Active
    type: percentage
    format: percentage
  - name: fmax_mhz
    label: Observed Fmax(MHz)
    type: number
  - name: mean_busy_mhz
    label: Mean Busy(MHz)
    type: number
  - name: eff_occupancy_pct
    label: Effective Occupancy
    type: percentage
    format: percentage
  - name: freq_coverage_pct
    label: Freq Coverage
    type: percentage
    format: percentage
save_as: frequency_residency
```
### GPU DVFS ramp events

- ID: `dvfs_ramp_events`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/dvfs_ramp_events.sql`](../sql/gpu_v57_ai_diagnostics/dvfs_ramp_events.sql)

```yaml
id: dvfs_ramp_events
type: atomic
optional: true
condition: frequency_residency.data?.length > 0
display:
  level: detail
  layer: list
  title: GPU DVFS Ramp Events
  columns:
  - name: gpu
    label: GPU
    type: number
  - name: gpu_name
    label: Name
    type: string
  - name: edge_rel_ns
    label: Edge(ns)
    type: duration
    unit: ns
  - name: idle_gap_ns
    label: Idle Gap(ns)
    type: duration
    unit: ns
  - name: freq_at_edge_mhz
    label: Edge Freq(MHz)
    type: number
  - name: target_mhz
    label: Target(MHz)
    type: number
  - name: ramp_ns
    label: Ramp(ns)
    type: duration
    unit: ns
  - name: completed
    label: Completed
    type: boolean
save_as: dvfs_ramp_events
```
### Sustained GPU throttle events

- ID: `sustained_throttle_events`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/sustained_throttle_events.sql`](../sql/gpu_v57_ai_diagnostics/sustained_throttle_events.sql)

```yaml
id: sustained_throttle_events
type: atomic
optional: true
condition: frequency_residency.data?.length > 0
display:
  level: detail
  layer: list
  title: Sustained GPU Throttle Events
  columns:
  - name: gpu
    label: GPU
    type: number
  - name: gpu_name
    label: Name
    type: string
  - name: start_rel_ns
    label: Start(ns)
    type: duration
    unit: ns
  - name: dur_ns
    label: Duration(ns)
    type: duration
    unit: ns
  - name: freq_mhz
    label: Freq(MHz)
    type: number
  - name: target_mhz
    label: Target(MHz)
    type: number
  - name: temp_c
    label: Temp(C)
    type: number
  - name: power_w
    label: Power(W)
    type: number
save_as: sustained_throttle_events
```
### GPU v57 no-data contract

- ID: `no_data_contract`
- Type: `atomic`
- SQL: [`../sql/gpu_v57_ai_diagnostics/no_data_contract.sql`](../sql/gpu_v57_ai_diagnostics/no_data_contract.sql)

```yaml
id: no_data_contract
type: atomic
optional: true
condition: data_check.data[0]?.gpu_activity_rows === 0 && data_check.data[0]?.gpufreq_tracks === 0
display:
  level: summary
  layer: overview
  title: GPU v57 Data Availability
  columns:
  - name: status
    label: Status
    type: string
  - name: gpu_rows
    label: GPU Rows
    type: number
  - name: gpu_activity_rows
    label: GPU Activity Rows
    type: number
  - name: gpufreq_tracks
    label: GPU Freq Tracks
    type: number
save_as: no_data_contract
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: timeline_occupancy
  description: Device-busy versus idle timeline decomposition translated from upstream gpu_timeline_decomposition.sql
- name: frequency_residency
  description: Busy-time clock residency and effective occupancy translated from upstream gpu_frequency_residency.sql
- name: dvfs_ramp_events
  description: Idle-to-busy clock ramp latency translated from upstream gpu_dvfs_ramp.sql
- name: sustained_throttle_events
  description: Sustained low-clock busy intervals translated from upstream gpu_sustained_throttle.sql
```
