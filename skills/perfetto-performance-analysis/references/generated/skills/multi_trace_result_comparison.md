GENERATED FILE - DO NOT EDIT.
Source: backend/skills/comparison/multi_trace_result_comparison.skill.yaml
Source SHA-256: 77585c59a25d4c89d4510b6d4017e3bd1d0e48dcd05e45064517414e5ec8a738
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# Multi Trace Result Comparison

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: multi_trace_result_comparison
version: 1.0.0
type: comparison
category: comparison
priority: high
```

## Metadata

```yaml
display_name: Multi Trace Result Comparison
description: Builds a comparison matrix from persisted analysis result snapshots, not live raw trace-pair panes.
tags:
- comparison
- analysis_result_snapshot
- multi_trace
```

## Triggers

```yaml
keywords:
  en:
  - result comparison
  - multi trace result comparison
  - snapshot comparison
  - analysis result snapshot comparison
patterns:
- compare .* analysis results
- compare .* snapshots
- compare .* result snapshots
```

## Inputs

```yaml
- name: snapshot_ids
  type: array
  required: true
  description: Ordered analysis result snapshot IDs to compare.
- name: baseline_snapshot_id
  type: string
  required: true
  description: Snapshot ID used as the comparison baseline.
- name: metric_keys
  type: array
  required: false
  description: Optional metric keys to include. Defaults to standard comparison metrics.
- name: query
  type: string
  required: false
  description: Original user comparison request.
```

## Comparison contract

```yaml
source: analysis_result_snapshot
operation: build_comparison_matrix
supports_backfill: true
required_inputs:
- snapshot_ids
- baseline_snapshot_id
output_contract: ComparisonMatrix
```

## Output and evidence contract

```yaml
display:
  title: Multi Trace Result Comparison
  format: table
  layer: overview
  level: summary
```
