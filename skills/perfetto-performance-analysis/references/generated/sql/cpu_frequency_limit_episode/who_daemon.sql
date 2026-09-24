-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_episode.skill.yaml
-- Source SHA-256: b02b4e752ee6809352b02fbf8267c6cd3900768a842fe46ba886cfc61a79bbbd
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Discovery vocabulary for thermal / performance-policy signals on Android.
--
-- These rows are HINTS FOR EXPLORATION, never evidence. A name match says a
-- track, slice or thread is worth inspecting with execute_sql; it does not say
-- the component caused anything, nor that its semantics match the name. Vendor
-- atrace counters are unversioned, undocumented and differ per SoC and per OEM
-- build, so the product must not encode their meaning as truth.
--
-- Consumers lowercase both the subject and the pattern before GLOB, so the
-- match is case-insensitive. `exclude_pattern` removes known false friends
-- (e.g. the meminfo CommitLimit counter for the generic `*limit*` probe).
-- `rank_hint` orders candidates for presentation only: 1 is the most specific.
thermal_signal_signatures AS (
  SELECT '*thermal-engine*' AS pattern, NULL AS exclude_pattern, 'thermal_daemon' AS signature_kind,
    'process_or_thread' AS match_target, 'qualcomm' AS platform_hint, 1 AS rank_hint,
    'Qualcomm userspace thermal daemon; writes cpufreq sysfs limits directly' AS note
  UNION ALL SELECT '*thermal-service*', NULL, 'thermal_daemon', 'process_or_thread', 'android_hal', 1,
    'Android thermal HAL service process (vendor implementation varies)'
  UNION ALL SELECT '*thermalext*', NULL, 'thermal_daemon', 'process_or_thread', 'oem', 1,
    'OEM/app-vendor thermal extension service'
  UNION ALL SELECT 'mi_thermald*', NULL, 'thermal_daemon', 'process_or_thread', 'xiaomi', 1,
    'Xiaomi thermal daemon'
  UNION ALL SELECT 'thermal_manager*', NULL, 'thermal_daemon', 'process_or_thread', 'oem', 1,
    'OEM thermal manager daemon'
  UNION ALL SELECT '*mtk*thermal*', NULL, 'thermal_daemon', 'process_or_thread', 'mediatek', 1,
    'MediaTek thermal component (unverified on this repository''s trace corpus)'
  UNION ALL SELECT 'thermal_*', NULL, 'thermal_kernel_thread', 'process_or_thread', 'kernel', 1,
    'Kernel thermal zone worker thread (e.g. thermal_BIG); polls a zone, does not prove mitigation'
  UNION ALL SELECT '*perfservice*', NULL, 'perf_policy_daemon', 'process_or_thread', 'oem', 2,
    'OEM performance policy service; may change frequency limits for non-thermal reasons'
  UNION ALL SELECT '*powerhal*', NULL, 'perf_policy_daemon', 'process_or_thread', 'android_hal', 2,
    'Power HAL; hints and boosts are not thermal mitigation'
  UNION ALL SELECT '*power-service*', NULL, 'perf_policy_daemon', 'process_or_thread', 'android_hal', 2,
    'Power HAL service process'
  UNION ALL SELECT '*perf2-hal*', NULL, 'perf_policy_daemon', 'process_or_thread', 'oem', 2,
    'OEM perf HAL variant'
  UNION ALL SELECT '*bperf*', NULL, 'perf_policy_daemon', 'process_or_thread', 'oem', 2,
    'OEM boost/perf daemon variant'
  UNION ALL SELECT '*cooling*', NULL, 'cooling_signal', 'counter_or_slice', 'generic', 1,
    'Cooling device naming; prefer the typed cooling_device_counter track'
  UNION ALL SELECT '*cdev*', NULL, 'cooling_signal', 'counter_or_slice', 'generic', 1,
    'Cooling device abbreviation used by vendor atrace counters'
  UNION ALL SELECT '*throttl*', NULL, 'throttle_signal', 'counter_or_slice', 'generic', 1,
    'Explicit throttling naming; semantics are vendor defined'
  UNION ALL SELECT '*mitigat*', NULL, 'throttle_signal', 'counter_or_slice', 'generic', 1,
    'Mitigation naming used by several vendor thermal stacks'
  UNION ALL SELECT '*therm*', NULL, 'thermal_signal', 'counter_or_slice', 'generic', 2,
    'Any thermal-named track or slice; also matches app and activity names'
  UNION ALL SELECT '*ceiling*', NULL, 'limit_request_signal', 'counter_or_slice', 'generic', 2,
    'Upper-bound request naming (e.g. cdev_ceiling)'
  UNION ALL SELECT '*floor*', NULL, 'limit_request_signal', 'counter_or_slice', 'generic', 2,
    'Lower-bound request naming (e.g. cdev_floor)'
  UNION ALL SELECT '*_request*', NULL, 'limit_request_signal', 'counter_or_slice', 'generic', 2,
    'Vendor limit-request counters (e.g. pid_request, hardlimit_request, final_request)'
  UNION ALL SELECT '*hint*', NULL, 'perf_hint_signal', 'counter_or_slice', 'generic', 3,
    'Performance/thermal hint counters; a hint is a request, not an applied limit'
  UNION ALL SELECT '*ppm*', NULL, 'perf_policy_signal', 'counter_or_slice', 'mediatek', 3,
    'MediaTek PPM (performance power management) naming'
  UNION ALL SELECT '*limit*', '*commit*limit*', 'limit_request_signal', 'counter_or_slice', 'generic', 3,
    'Generic limit naming; the meminfo CommitLimit counter is excluded as a false friend'
  -- Non-CPU heat producers. Presence of these processes in a window is a
  -- reminder that CPU work is not the only thermal input; it is not a claim
  -- that they heated the device.
  UNION ALL SELECT '*camera*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Camera stack; sustained capture is a well known non-CPU heat source'
  UNION ALL SELECT '*mediacodec*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Hardware codec service; encode/decode load is not visible as CPU time'
  UNION ALL SELECT '*mediaserver*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 2,
    'Media server process'
  UNION ALL SELECT '*modem*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Modem-side service; radio activity heats the SoC without CPU time'
  UNION ALL SELECT '*ril*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 2,
    'Radio interface layer'
  UNION ALL SELECT '*cnss*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'qualcomm', 2,
    'Qualcomm connectivity subsystem daemon'
  UNION ALL SELECT '*dsp*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 2,
    'DSP (adsp/cdsp/slpi) services; offloaded compute is not CPU time'
  UNION ALL SELECT '*charg*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Charging service; charging is a direct heat source independent of workload'
)
,
-- Threads whose own or process name matches a process_or_thread signature,
-- one row per thread with its most specific pattern. Perf-policy daemons are
-- included here (they are candidates for NON-thermal limiting) and filtered
-- out of thermal_daemon_threads below. Consumers that need this in several
-- steps recompute it per step; it is not materialised by the engine.
thermal_signal_threads AS (
  SELECT utid, thread_name, process_name, pattern, signature_kind, platform_hint, rank_hint
  FROM (
    SELECT t.utid, COALESCE(t.name, '') AS thread_name, COALESCE(p.name, '') AS process_name,
      sig.pattern, sig.signature_kind, sig.platform_hint, sig.rank_hint,
      ROW_NUMBER() OVER (PARTITION BY t.utid ORDER BY sig.rank_hint, sig.pattern) AS rn
    FROM thread t
    LEFT JOIN process p ON p.upid = t.upid
    JOIN thermal_signal_signatures sig ON sig.match_target = 'process_or_thread'
      AND (LOWER(COALESCE(t.name, '')) GLOB sig.pattern
        OR LOWER(COALESCE(p.name, '')) GLOB sig.pattern)
  ) WHERE rn = 1
),
thermal_daemon_threads AS (
  SELECT utid FROM thermal_signal_threads
  WHERE signature_kind IN ('thermal_daemon', 'thermal_kernel_thread')
)
,
win AS (
  SELECT ${episode_windows.data[0].who_start_ts} AS who_start_ts,
    ${episode_windows.data[0].who_end_ts} AS who_end_ts
),
trace_span AS (
  SELECT MIN(ts) AS span_start, MAX(ts + MAX(dur, 0)) AS span_end FROM sched_slice
),
activity AS (
  SELECT d.utid,
    SUM(CASE WHEN s.ts < (SELECT who_end_ts FROM win) AND s.ts + s.dur > (SELECT who_start_ts FROM win)
      THEN MIN(s.ts + s.dur, (SELECT who_end_ts FROM win)) - MAX(s.ts, (SELECT who_start_ts FROM win))
      ELSE 0 END) AS who_running_ns,
    SUM(CASE WHEN s.ts < (SELECT who_end_ts FROM win) AND s.ts + s.dur > (SELECT who_start_ts FROM win)
      THEN 1 ELSE 0 END) AS who_slice_count,
    SUM(CASE WHEN s.ts < ${episode_start_ts} AND s.ts + s.dur > (SELECT who_start_ts FROM win)
      THEN MIN(s.ts + s.dur, ${episode_start_ts}) - MAX(s.ts, (SELECT who_start_ts FROM win))
      ELSE 0 END) AS ran_before_limit_ns,
    MAX(CASE WHEN s.ts < ${episode_start_ts} AND s.ts + s.dur > (SELECT who_start_ts FROM win)
      THEN MIN(s.ts + s.dur, ${episode_start_ts}) END) AS last_run_end_before_ts,
    SUM(s.dur) AS trace_running_ns
  FROM thermal_signal_threads d
  JOIN sched_slice s ON s.utid = d.utid AND s.dur > 0
  GROUP BY d.utid
)
SELECT d.process_name, d.thread_name, d.signature_kind, d.platform_hint,
  d.pattern AS matched_pattern,
  a.who_running_ns, a.who_slice_count,
  ROUND(a.who_running_ns * 1e9 / NULLIF((SELECT who_end_ts - who_start_ts FROM win), 0), 1) AS who_rate_ns_per_s,
  ROUND(a.trace_running_ns * 1e9 / NULLIF((SELECT span_end - span_start FROM trace_span), 0), 1) AS baseline_rate_ns_per_s,
  ROUND(
    (a.who_running_ns * 1.0 / NULLIF((SELECT who_end_ts - who_start_ts FROM win), 0))
    / NULLIF(a.trace_running_ns * 1.0 / NULLIF((SELECT span_end - span_start FROM trace_span), 0), 0), 2) AS rate_ratio,
  a.ran_before_limit_ns, a.last_run_end_before_ts,
  CASE WHEN a.last_run_end_before_ts IS NOT NULL
    THEN ${episode_start_ts} - a.last_run_end_before_ts END AS lead_ns,
  'thermal_signal_signatures.name_glob_candidate_not_proof' AS match_basis,
  'observation_not_causal' AS evidence_scope
FROM thermal_signal_threads d
JOIN activity a ON a.utid = d.utid
WHERE a.who_running_ns > 0
ORDER BY a.ran_before_limit_ns DESC, a.who_running_ns DESC
LIMIT 30
