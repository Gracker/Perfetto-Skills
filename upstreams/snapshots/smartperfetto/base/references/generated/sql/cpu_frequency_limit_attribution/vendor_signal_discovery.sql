-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
-- Source SHA-256: 9b27b3315b361c5cd21809d36d2415240a89ae8baf023b849ee3a4a8ba068888
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
  SELECT ${analysis_window.data[0].window_start_ts} AS window_start_ts,
    ${analysis_window.data[0].window_end_ts} AS window_end_ts
),
counter_sig AS (
  SELECT * FROM thermal_signal_signatures WHERE match_target = 'counter_or_slice'
),
thread_sig AS (
  SELECT * FROM thermal_signal_signatures WHERE match_target = 'process_or_thread'
),
matched_counter_tracks AS (
  SELECT ct.id AS track_id, ct.name AS candidate_name, ct.type AS track_type,
    s.pattern, s.signature_kind, s.platform_hint, s.rank_hint,
    ROW_NUMBER() OVER (PARTITION BY ct.id ORDER BY s.rank_hint, s.pattern) AS rn
  FROM counter_track ct
  JOIN counter_sig s ON LOWER(ct.name) GLOB s.pattern
    AND (s.exclude_pattern IS NULL OR LOWER(ct.name) NOT GLOB s.exclude_pattern)
),
counter_candidates AS (
  SELECT 'counter_track' AS candidate_kind, m.candidate_name, m.track_type,
    COALESCE(p.name, '') AS source_process,
    m.signature_kind, m.platform_hint, m.pattern AS matched_pattern, m.rank_hint,
    COUNT(c.id) AS sample_count, MIN(c.ts) AS first_ts, MAX(c.ts) AS last_ts
  FROM matched_counter_tracks m
  JOIN counter c ON c.track_id = m.track_id
  LEFT JOIN process_counter_track pct ON pct.id = m.track_id
  LEFT JOIN process p ON p.upid = pct.upid
  WHERE m.rn = 1
    AND c.ts >= (SELECT window_start_ts FROM win)
    AND c.ts < (SELECT window_end_ts FROM win)
  GROUP BY m.track_id, m.candidate_name, m.track_type, p.name,
    m.signature_kind, m.platform_hint, m.pattern, m.rank_hint
),
window_slice_names AS (
  SELECT sl.name AS candidate_name, COUNT(*) AS sample_count,
    MIN(sl.ts) AS first_ts, MAX(sl.ts) AS last_ts, MIN(sl.id) AS sample_slice_id
  FROM slice sl
  WHERE sl.ts >= (SELECT window_start_ts FROM win)
    AND sl.ts < (SELECT window_end_ts FROM win)
  GROUP BY sl.name
),
matched_slice_names AS (
  SELECT w.candidate_name, w.sample_count, w.first_ts, w.last_ts, w.sample_slice_id,
    s.pattern, s.signature_kind, s.platform_hint, s.rank_hint,
    ROW_NUMBER() OVER (PARTITION BY w.candidate_name ORDER BY s.rank_hint, s.pattern) AS rn
  FROM window_slice_names w
  JOIN counter_sig s ON LOWER(w.candidate_name) GLOB s.pattern
    AND (s.exclude_pattern IS NULL OR LOWER(w.candidate_name) NOT GLOB s.exclude_pattern)
),
slice_candidates AS (
  SELECT 'slice' AS candidate_kind, m.candidate_name, 'slice' AS track_type,
    COALESCE(p.name, '') AS source_process,
    m.signature_kind, m.platform_hint, m.pattern AS matched_pattern, m.rank_hint,
    m.sample_count, m.first_ts, m.last_ts
  FROM matched_slice_names m
  LEFT JOIN slice sl ON sl.id = m.sample_slice_id
  LEFT JOIN thread_track tt ON tt.id = sl.track_id
  LEFT JOIN thread th ON th.utid = tt.utid
  LEFT JOIN process_track ptr ON ptr.id = sl.track_id
  LEFT JOIN process p ON p.upid = COALESCE(th.upid, ptr.upid)
  WHERE m.rn = 1
),
matched_threads AS (
  SELECT t.utid, COALESCE(t.name, '') AS candidate_name,
    COALESCE(p.name, '') AS source_process,
    s.pattern, s.signature_kind, s.platform_hint, s.rank_hint,
    ROW_NUMBER() OVER (PARTITION BY t.utid ORDER BY s.rank_hint, s.pattern) AS rn
  FROM thread t
  LEFT JOIN process p ON p.upid = t.upid
  JOIN thread_sig s ON (LOWER(COALESCE(t.name, '')) GLOB s.pattern
    OR LOWER(COALESCE(p.name, '')) GLOB s.pattern)
),
thread_candidates AS (
  SELECT 'thread' AS candidate_kind, m.candidate_name, 'sched' AS track_type,
    m.source_process, m.signature_kind, m.platform_hint, m.pattern AS matched_pattern,
    m.rank_hint,
    COUNT(sc.id) AS sample_count, MIN(sc.ts) AS first_ts, MAX(sc.ts + sc.dur) AS last_ts
  FROM matched_threads m
  JOIN sched_slice sc ON sc.utid = m.utid AND sc.dur > 0
    AND sc.ts < (SELECT window_end_ts FROM win)
    AND sc.ts + sc.dur > (SELECT window_start_ts FROM win)
  WHERE m.rn = 1
  GROUP BY m.utid, m.candidate_name, m.source_process, m.signature_kind,
    m.platform_hint, m.pattern, m.rank_hint
),
unioned AS (
  SELECT * FROM counter_candidates
  UNION ALL SELECT * FROM slice_candidates
  UNION ALL SELECT * FROM thread_candidates
),
-- Interleave the three candidate kinds. Ranking purely by rank_hint lets
-- one prolific kind (a Pixel emits dozens of VIRTUAL-SKIN-*-cdev_* atrace
-- counters) consume the whole row budget and hide the thermal HAL slices
-- and kernel thermal threads the reader also needs to see.
ranked AS (
  SELECT u.*,
    ROW_NUMBER() OVER (PARTITION BY u.candidate_kind
      ORDER BY u.rank_hint, u.sample_count DESC, u.candidate_name) AS kind_rank
  FROM unioned u
)
SELECT r.candidate_kind, r.candidate_name, r.track_type, r.source_process,
  r.signature_kind, r.platform_hint, r.matched_pattern,
  r.sample_count, r.first_ts, r.last_ts,
  '名称匹配只说明值得用 execute_sql 查看这条轨道/slice/线程；名称是数据，不是语义或证据。厂商计数器的单位与含义按 SoC 与 ROM 版本而异，未经核实不得当作限频原因。' AS exploration_hint,
  'discovery_candidate_not_evidence' AS evidence_scope
FROM ranked r
ORDER BY r.kind_rank, r.rank_hint, r.candidate_kind, r.sample_count DESC
LIMIT ${max_discovery_rows|60}
