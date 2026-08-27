GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/code_pinpoint.skill.yaml
Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
Source commit: 908d0897b0ae6b329d598f6d033a17543a62632a
Perfetto-Skills native overlay: deterministic trace-to-source anchors with owned fixture regressions.
# Deterministic code pinpoint anchors

Use this portable workflow to extract trace-derived names and sampled symbols
that can be searched in an independently available source tree. Treat every
row as an anchor candidate: the trace proves that the event or sample existed,
but it does not prove which source revision produced a historical capture.

## Overview

```yaml
name: code_pinpoint
version: '1.1'
type: composite
tier: S
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Exact process/package name; package subprocesses use the package: suffix form.
- name: start_ts
  type: timestamp
  required: false
  description: Inclusive start timestamp in nanoseconds.
- name: end_ts
  type: timestamp
  required: false
  description: Inclusive end timestamp in nanoseconds.
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
- process_name
rewriteTo: recommended_process_name_param
```

## Ordered execution

### Trace slice anchors

- ID: `hot_slices`
- Type: `atomic`
- SQL: [`../sql/code_pinpoint/hot_slices.sql`](../sql/code_pinpoint/hot_slices.sql)

The output column order is stable:

```yaml
display:
  level: detail
  layer: list
  title: Code Pinpoint Candidates
  columns:
  - name: slice_id
    type: number
  - name: ts
    type: timestamp
    unit: ns
  - name: dur_ms
    type: duration
    unit: ms
  - name: upid
    type: number
  - name: utid
    type: number
  - name: process_name
    type: string
  - name: thread_name
    type: string
  - name: slice_name
    type: string
  - name: anchor_kind
    type: string
  - name: source_query_hint
    type: string
synthesize:
  role: list
  fields:
  - key: slice_name
  - key: anchor_kind
  - key: source_query_hint
```

`source_query_hint` is copied only from a trace-derived searchable name. A
plain span that does not carry such a name uses `generic_anchor_only` and a
null hint; never invent a class, function, file, or package from context.

### Sampled native symbols

- ID: `native_symbols`
- Type: `atomic`
- SQL: [`../sql/code_pinpoint/native_modules.sql`](../sql/code_pinpoint/native_modules.sql)

```yaml
display:
  level: debug
  layer: deep
  title: Native Symbol Anchors
  columns:
  - name: function_name
    type: string
  - name: module_name
    type: string
  - name: build_id
    type: string
  - name: sample_count
    type: number
synthesize:
  role: list
  fields:
  - key: function_name
  - key: module_name
  - key: build_id
  - key: sample_count
optional: true
on_empty: 'no_symbol_data: no CPU profiling symbols match the selected process and time window'
```

This query starts from `perf_sample`, resolves its callsite frame and mapping,
and then groups actual sampled functions. It applies the same exact
process/package-subprocess rule and the same start/end window as the slice
query. It never substitutes placeholder symbols or build IDs. If profiling
data is absent, preserve the explicit `no_symbol_data` status.
