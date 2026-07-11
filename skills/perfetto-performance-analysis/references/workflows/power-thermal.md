# Power and thermal

## Purpose

Explain energy, battery drain, wakelocks, doze/background work, thermal state, and throttling.

## Inputs

Require a trace, target process or device-wide question, time range, and available power/thermal instrumentation.

## Availability gate

Confirm rails or Wattson support, battery counters, wakelocks, CPU/GPU frequency, thermal sensors, and device state.

## Evidence sequence

Start with [power overview](../generated/skills/power_consumption_overview.md)
and [battery attribution](../generated/skills/battery_drain_attribution.md), using
only supported rails, Wattson, or counter models. Inspect wakelocks, jobs,
network/modem, screen/doze state, CPU/GPU work, then use
[thermal throttling](../generated/skills/thermal_throttling.md) to test
temperature, cooling/policy, and effective frequency caps.

## Interpretation boundaries

Do not convert unsupported counters into energy. Distinguish workload demand, policy response, thermal cap, and temporal correlation.

## Deep dives

Branch into rails/Wattson, wakelocks, modem/network, background CPU, GPU, and thermal chains when available.

## Report requirements

Report measurement method, scope, attribution coverage, thermal/policy evidence, uncertainty, and missing sensors.
