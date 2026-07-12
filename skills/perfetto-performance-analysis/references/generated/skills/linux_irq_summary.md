GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_irq_summary.skill.yaml
Source SHA-256: 5ed6c6bb88f94df602ca5a751e53d30bec9514dcbff8bb6ece838bfcb963369d
Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf
# IRQ 中断汇总

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_irq_summary
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: IRQ 中断汇总
description: 硬/软中断次数与耗时统计
icon: bolt
tags:
- irq
- kernel
- hard_irq
- soft_irq
- atomic
```

## Prerequisites

```yaml
modules:
- linux.irqs
```

## Ordered execution

### IRQ 汇总

- ID: `irq_summary`
- Type: `atomic`
- SQL: [`../sql/linux_irq_summary/irq_summary.sql`](../sql/linux_irq_summary/irq_summary.sql)

```yaml
id: irq_summary
type: atomic
display:
  level: detail
  layer: list
  title: 硬/软 IRQ 次数与耗时
  columns:
  - name: name
    label: 中断名
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时(ms)
    type: duration
    format: duration_ms
  - name: avg_dur_us
    label: 平均耗时(μs)
    type: duration
    format: compact
```
