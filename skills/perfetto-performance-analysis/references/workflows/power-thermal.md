# Power and thermal

## Purpose

Explain energy, battery drain, wakelocks, doze/background work, thermal state, and throttling.

## Inputs

Require a trace, target process or device-wide question, time range, and available power/thermal instrumentation.

## Availability gate

Confirm rails or Wattson support, battery counters, wakelocks, CPU/GPU frequency, thermal sensors, and device state.

## Evidence sequence

Measure available energy/power signals; attribute supported CPU/thread or rail contributions; inspect wakelocks, jobs, network/modem, screen/doze state, temperature, and frequency caps. Search `references/generated/` for `power_consumption_overview`, `battery_drain_attribution`, and `thermal_throttling` after export.

## Interpretation boundaries

Do not convert unsupported counters into energy. Distinguish workload demand, policy response, thermal cap, and temporal correlation.

## Deep dives

Branch into rails/Wattson, wakelocks, modem/network, background CPU, GPU, and thermal chains when available.

## Report requirements

Report measurement method, scope, attribution coverage, thermal/policy evidence, uncertainty, and missing sensors.

