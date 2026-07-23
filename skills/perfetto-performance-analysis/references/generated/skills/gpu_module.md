GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/hardware/gpu_module.skill.yaml
Source SHA-256: 6dd740df9f3de46527f96908cf6ac30d71767e6f61d2bc2d6544f825cbbc3551
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# GPU 硬件分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gpu_module
version: '1.0'
type: composite
category: hardware
```

## Metadata

```yaml
display_name: GPU 硬件分析
description: 分析 GPU 渲染、频率和显存使用
tags:
- hardware
- gpu
- render
- frequency
- memory
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
```

## Module contract

```yaml
layer: hardware
component: GPU
subsystems:
- frequency
- rendering
- memory
relatedModules:
- framework_surfaceflinger
- hardware_cpu
- hardware_memory
```

## Dialogue guidance

```yaml
capabilities:
- id: gpu_rendering_analysis
  questionTemplate: How is GPU rendering performing for package {package}?
  requiredParams:
  - package
  description: Analyze GPU rendering performance
- id: gpu_frequency_analysis
  questionTemplate: What is the GPU frequency during the trace?
  requiredParams: []
  description: Analyze GPU frequency and utilization
- id: gpu_memory_analysis
  questionTemplate: What is the GPU memory usage?
  requiredParams: []
  optionalParams:
  - package
  description: Analyze GPU memory allocation
findingsSchema:
- id: gpu_bottleneck
  severity: critical
  titleTemplate: 'GPU bottleneck: render time {render_ms}ms exceeds frame budget'
  descriptionTemplate: GPU rendering taking {render_ms}ms, causing frame drops
  evidenceFields:
  - render_ms
  - frame_budget_ms
  - gpu_util_pct
- id: gpu_frequency_low
  severity: warning
  titleTemplate: 'GPU frequency low: {avg_freq_mhz}MHz'
  descriptionTemplate: GPU running at reduced frequency, possible thermal throttling
  evidenceFields:
  - avg_freq_mhz
  - max_freq_mhz
- id: high_overdraw
  severity: warning
  titleTemplate: 'High overdraw detected: {overdraw_ratio}x'
  descriptionTemplate: Screen pixels being drawn {overdraw_ratio} times on average
  evidenceFields:
  - overdraw_ratio
suggestionsSchema:
- id: check_thermal_for_gpu
  condition: gpu_freq_low == true
  targetModule: thermal_module
  questionTemplate: Is thermal throttling affecting GPU?
  paramsMapping: {}
  priority: 1
- id: check_surfaceflinger
  condition: composition_slow == true
  targetModule: surfaceflinger_module
  questionTemplate: What is causing slow GPU composition?
  paramsMapping:
    package: package
  priority: 1
```

## Ordered execution

### GPU 频率概览

- ID: `gpu_frequency_overview`
- Type: `atomic`
- SQL: [`../sql/gpu_module/gpu_frequency_overview.sql`](../sql/gpu_module/gpu_frequency_overview.sql)

```yaml
id: gpu_frequency_overview
type: atomic
display:
  level: key
  layer: overview
  title: GPU 频率概览
save_as: gpu_freq
synthesize: true
```
### GPU 利用率

- ID: `gpu_utilization`
- Type: `atomic`
- SQL: [`../sql/gpu_module/gpu_utilization.sql`](../sql/gpu_module/gpu_utilization.sql)

```yaml
id: gpu_utilization
type: atomic
display:
  level: detail
  layer: overview
  title: GPU 利用率
save_as: gpu_util
```
### RenderThread GPU 耗时

- ID: `render_thread_gpu`
- Type: `atomic`
- SQL: [`../sql/gpu_module/render_thread_gpu.sql`](../sql/gpu_module/render_thread_gpu.sql)

```yaml
id: render_thread_gpu
type: atomic
display:
  level: detail
  layer: overview
  title: RenderThread GPU 耗时
save_as: render_gpu
synthesize:
  role: detail
  fields:
  - key: total_gpu_ms
    label: 总 GPU 耗时
    format: '{{value}}ms'
  - key: avg_gpu_ms
    label: 平均 GPU 耗时
    format: '{{value}}ms'
```
### 慢 GPU 操作

- ID: `slow_gpu_operations`
- Type: `atomic`
- SQL: [`../sql/gpu_module/slow_gpu_operations.sql`](../sql/gpu_module/slow_gpu_operations.sql)

```yaml
id: slow_gpu_operations
type: atomic
display:
  level: detail
  layer: list
  title: 慢 GPU 操作列表
save_as: slow_gpu_ops
```
### GPU 诊断

- ID: `gpu_diagnosis`
- Type: `diagnostic`

```yaml
id: gpu_diagnosis
type: diagnostic
inputs:
- gpu_freq
- gpu_util
- render_gpu
- slow_gpu_ops
rules:
- condition: render_gpu.data[0]?.avg_gpu_ms > 8
  diagnosis: RenderThread GPU 平均耗时过长 (${render_gpu.data[0]?.avg_gpu_ms}ms)，超过帧预算
  confidence: high
  suggestions:
  - 减少过度绘制
  - 简化 shader 复杂度
  - 减少纹理大小
  evidence_fields:
  - render_gpu.data[0].avg_gpu_ms
  - render_gpu.data[0].max_gpu_ms
- condition: slow_gpu_ops.data.length > 10
  diagnosis: 存在 ${slow_gpu_ops.data.length} 次慢 GPU 操作
  confidence: high
  suggestions:
  - 分析具体慢操作的原因
  - 检查是否有大纹理上传
  evidence_fields:
  - slow_gpu_ops.data.length
  - slow_gpu_ops.data[0]?.dur_ms
- condition: gpu_util.data[0]?.avg_value > 90
  diagnosis: GPU 利用率过高 (${gpu_util.data[0]?.avg_value}%)，接近饱和
  confidence: medium
  suggestions:
  - 降低渲染复杂度
  - 考虑降低分辨率
  evidence_fields:
  - gpu_util.data[0].avg_value
display:
  level: key
  layer: overview
  title: GPU 诊断结果
```
