GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-thermal-throttling.template.md
Source SHA-256: ff0bb590ff50f6eb686cac1cd29723dafbe402ae6ff7a515bba0ca6a3a2f8df1
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

# Knowledge Thermal Throttling Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) | the portable runtime -->

# Thermal Throttling

## Mechanism

Android devices contain multiple thermal sensors monitoring SoC junction temperature, battery temperature, and skin temperature. When any sensor exceeds a defined threshold, the **thermal governor** intervenes by reducing CPU and GPU frequency caps, limiting the maximum performance available to the system.

### Throttle Chain

```
Sustained workload → heat generation → thermal zone exceeds threshold
    → governor reduces frequency cap → CPU/GPU run slower
    → frame rendering takes longer → frames miss VSync deadline → jank
```

### Hysteresis

Thermal management uses hysteresis to prevent rapid oscillation. Once throttling activates at threshold T1 (e.g., 85C), it does not deactivate until temperature drops below a lower threshold T2 (e.g., 80C). This means:
- Throttling onset can lag the actual hot workload by seconds
- Recovery takes longer than expected -- temperature must drop significantly before full performance restores
- Users experience prolonged jank even after the heavy workload ends

### Sustained vs Burst Workloads

- **Burst** (< 2s): Brief spikes rarely trigger throttling. The thermal mass of the SoC absorbs short bursts.
- **Sustained** (> 5-10s): Continuous high load accumulates heat until throttle thresholds are reached.
- Gaming, video recording, benchmarks, and scroll-through-large-lists scenarios are common sustained workload triggers.

## Trace Signatures

| What to Look For | Meaning |
|-----------------|---------|
| `android_dvfs_counters` | Frequency caps imposed by thermal governor |
| `cpu_frequency_counters` | Actual operating frequency -- compare against max to detect capping |
| `thermal_zone` counters | Raw temperature readings from SoC sensors |
| Actual freq << max supported freq | Active thermal throttling |
| Frequency dropping mid-trace | Throttle onset -- correlate with jank increase |
| GPU frequency counters | GPU throttling (affects DrawFrame duration) |

### Detection Pattern

Compare the CPU frequency in the first 5 seconds of the trace (before thermal buildup) against the frequency during the janky period. A significant drop (e.g., big core going from 2.8GHz to 1.8GHz) confirms thermal throttling as a contributing factor.

## Typical Solutions

- **Reduce sustained CPU/GPU load**: Optimize shaders, reduce overdraw, simplify animations
- **Implement frame pacing**: Deliver consistent work per frame instead of bursty patterns. Inconsistent frame times cause higher peak temperatures
- **Offload to RenderThread**: Move draw work off the main thread to distribute heat across cores
- **Avoid busy-wait patterns**: Spin loops generate maximum heat with no useful work
- **Reduce background work during performance-critical paths**: Pause non-essential jobs during scrolling or animation
- **Consider workload spreading**: Distribute computation across multiple cores rather than saturating one core
