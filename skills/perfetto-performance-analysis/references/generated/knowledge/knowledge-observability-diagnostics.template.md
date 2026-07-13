GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-observability-diagnostics.template.md
Source SHA-256: 3493c6dce3f2cb2399f1c75f3147768c329cdf69f7821e3c410f0da73e0c972f
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

# Knowledge Observability Diagnostics Template

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

# Observability And Diagnostic API Boundaries

Verified against Android official docs on 2026-05-30. Use this topic when a
report mentions `ApplicationExitInfo`, `ApplicationStartInfo`,
`ProfilingManager`, `ProfilingTrigger`, Android/Play Vitals, App Performance
Score, online APM, or A/B experiments.

## Evidence Classes

- `trace_direct`: current Perfetto trace facts: slices, thread states, ANR
  windows, startup timing, frames, memory counters, power events, and Skill/SQL
  metrics. This proves only the captured window.
- `diagnostic_api`: versioned Android APIs such as `ApplicationExitInfo` and
  `ApplicationStartInfo`. These records can explain historical exits or starts
  but need API level, process identity, timestamps, reason/state, and current
  trace alignment.
- `profiling_artifact`: `ProfilingManager` / `ProfilingTrigger` output such as
  system trace snapshots, Java heap dumps, heap profiles, and stack samples.
  Artifacts are evidence only after result status, file/time, process, and
  trigger/profiling type are known.
- `external_aggregate`: Play Vitals, App Performance Score, Firebase
  Performance, APM, server dashboards, and quality scores. These are aggregate
  or device/run dependent background signals.
- `experiment_or_ab`: A/B or rollout data. Require stable assignment unit,
  activation point, primary metric, guardrails, sample health, and A/A sanity.
- `missing_evidence`: absent records/artifacts are a reportable limitation and
  recapture action, not proof that the issue is absent.

## API Boundaries

- `ApplicationExitInfo` is available through
  `ActivityManager.getHistoricalProcessExitReasons()` on API 30+. Android stores
  recent records in a ring buffer; use package/pid/max filters carefully. Treat
  `description` as human-readable context, not a stable schema. `getAnrInfo()`
  is API 37 and is populated only when the reason is `REASON_ANR`.
- `ApplicationStartInfo` is available through
  `ActivityManager.getHistoricalProcessStartReasons()` on API 35+. Records may
  include in-progress or incomplete startups. `getStartComponent()` is API 36
  and distinguishes activity, service, broadcast, and content-provider starts.
  Compare ApplicationStartInfo timestamps with Perfetto startup windows only
  after clock/record-state alignment.
- `ProfilingManager.requestProfiling()` is API 35 and can request Java heap
  dumps, heap profiles, stack samples, and system traces. Requests are rate
  limited and not guaranteed.
- `ProfilingManager.addProfilingTriggers()` is API 36; `addAllProfilingTriggers`
  and running-trace trigger support are version 36.1. `TRIGGER_TYPE_ANR` and
  `TRIGGER_TYPE_APP_FULLY_DRAWN` are API 36; `TRIGGER_TYPE_OOM` is API 37.
  Some kill/excessive-CPU/cold-start trigger constants are newer and must stay
  version-gated. Trigger output still needs artifact/result evidence.

## External Metrics And Experiments

- Android/Play Vitals are Play/Reporting aggregate signals, not the same as a
  single trace. They are useful for impact and prioritization, but trace-local
  root cause still needs current-window evidence.
- App Performance Score is a preview/current-policy-sensitive assessment.
  Dynamic score is device/run dependent; static score depends on project
  configuration and tool adoption. Do not use the score alone as a root cause.
- Online APM and server metrics can supply population, release, device, and
  backend context. Align them by app version, device class, timestamp, trace id,
  request id, or experiment arm before increasing confidence.
- A/B evidence needs treatment/control assignment, activation after config is
  active, one primary metric, guardrails, sample-ratio checks, and A/A sanity.
  A/B results can support rollout decisions but do not replace trace evidence
  for "why this specific trace is slow".

## Report Pattern

1. Name the source class: `trace_direct`, `diagnostic_api`,
   `profiling_artifact`, `external_aggregate`, `experiment_or_ab`, or
   `missing_evidence`.
2. State API/Android version, result/record state, process identity, timestamp,
   and artifact path or metric window when present.
3. Align the external record to the current trace window, or explicitly say it
   is unaligned context.
4. Keep the root-cause wording proportional: diagnostic APIs and aggregates
   can raise or lower confidence only when they align with trace-local evidence.
