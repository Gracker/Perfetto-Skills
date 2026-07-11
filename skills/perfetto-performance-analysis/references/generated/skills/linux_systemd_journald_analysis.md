GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_systemd_journald_analysis.skill.yaml
Source SHA-256: cd2cf0fd458e13893bab21974f26f9653bd1d4fe8b5fc6c41687bed42288a561
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# Linux systemd-journald Analysis

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_systemd_journald_analysis
version: '1.0'
type: atomic
category: system
tier: B
```

## Metadata

```yaml
display_name: Linux systemd-journald Analysis
description: Summarize v57 linux.systemd_journald log entries, prioritizing warning and error evidence
icon: article
tags:
- linux
- systemd
- journald
- logs
- upstream_v57
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - journald
  - systemd 日志
  - Linux 日志
  - 系统日志
  en:
  - journald
  - systemd
  - linux logs
  - syslog
patterns:
- .*(journald|systemd).*
- .*(linux|syslog).*logs?.*
```

## Prerequisites

```yaml
modules:
- linux.systemd_journald
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
- name: unit
  type: string
  required: false
  description: Optional systemd unit substring
- name: tag
  type: string
  required: false
  description: Optional SYSLOG_IDENTIFIER/program substring
- name: max_prio
  type: integer
  required: false
  default: 4
  description: Maximum syslog priority to show by default; lower is more severe, 4 means warnings and above
- name: max_rows
  type: integer
  required: false
  default: 80
  description: Maximum rows to return
```

## Query

Run [`../sql/linux_systemd_journald_analysis/query.sql`](../sql/linux_systemd_journald_analysis/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
fields:
- name: signal_type
  description: Classification derived from syslog priority plus high-signal error keywords
- name: prio_label
  description: Syslog priority label; lower numeric priorities are more severe
```

## Display metadata

```yaml
level: summary
layer: list
title: systemd-journald Signals
columns:
- name: ts_str
  label: Timestamp
  type: timestamp
  unit: ns
- name: prio_label
  label: Priority
  type: string
- name: signal_type
  label: Signal
  type: string
- name: tag
  label: Tag
  type: string
- name: comm
  label: Comm
  type: string
- name: systemd_unit
  label: Unit
  type: string
- name: hostname
  label: Host
  type: string
- name: transport
  label: Transport
  type: string
- name: msg_preview
  label: Message
  type: string
```
