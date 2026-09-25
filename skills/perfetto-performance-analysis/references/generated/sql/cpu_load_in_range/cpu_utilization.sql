-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
-- Source SHA-256: b24f5a2e47a5f0d7ae34fcfc86c1a7f58e53b09f13f6b5e6e36b5a998da2053c
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Global CPU spans retain peer identity. Consumers join system_target_threads
-- explicitly; no global process-table replacement or synthetic switch boundary.
-- Capacity extrema require a complete machine population. A missing capacity
-- on any CPU prevents certifying which recorded CPU is fastest or smallest.
system_cpu_topology AS (
  SELECT c.id AS ucpu,c.cpu,c.machine_id,c.cluster_id,c.capacity,
    CASE WHEN c.recorded_capacity_count<c.machine_cpu_count THEN 'unknown'
      WHEN c.min_capacity=c.max_capacity THEN 'unknown'
      WHEN c.capacity=c.min_capacity THEN 'little'
      WHEN c.capacity=c.max_capacity THEN 'big'
      ELSE 'medium' END AS core_type,
    CASE WHEN c.recorded_capacity_count=0 THEN 'capacity_unavailable'
      WHEN c.recorded_capacity_count<c.machine_cpu_count THEN 'capacity_incomplete'
      WHEN c.min_capacity=c.max_capacity THEN 'capacity_uniform_no_big_little'
      ELSE 'recorded_capacity' END AS topology_source
  FROM (
    SELECT cpu.*,
      COUNT(*) OVER (PARTITION BY machine_id) AS machine_cpu_count,
      COUNT(CASE WHEN capacity>0 THEN 1 END) OVER (PARTITION BY machine_id) AS recorded_capacity_count,
      MIN(CASE WHEN capacity>0 THEN capacity END) OVER (PARTITION BY machine_id) AS min_capacity,
      MAX(CASE WHEN capacity>0 THEN capacity END) OVER (PARTITION BY machine_id) AS max_capacity
    FROM cpu
  ) c
),
system_sched_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    s.id AS sched_id, s.utid, t.upid, t.is_idle, s.cpu, s.ucpu,
    s.ts AS raw_start_ts, s.dur AS raw_dur,
    CASE WHEN s.dur >= 0 THEN s.ts + s.dur END AS raw_end_ts,
    MAX(s.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, w.window_end_ts) - MAX(s.ts, w.window_start_ts) AS dur_ns,
    s.dur = -1 AS is_unfinished,
    s.ts < w.window_start_ts AS left_censored,
    s.dur = -1 OR s.ts + s.dur > w.window_end_ts AS right_censored,
    s.end_state, s.priority,
    ct.machine_id, ct.cluster_id, ct.capacity,
    COALESCE(ct.core_type, 'unknown') AS core_type,
    COALESCE(ct.topology_source, 'cpu_identity_unavailable') AS topology_source
  FROM system_windows w JOIN sched_slice s
    ON s.ts < w.window_end_ts AND s.dur >= -1 AND s.dur != 0
      AND CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
        ELSE s.ts + s.dur END > w.window_start_ts
  LEFT JOIN thread t ON t.utid = s.utid
  LEFT JOIN system_cpu_topology ct ON ct.ucpu = s.ucpu
  WHERE w.window_end_ts > w.window_start_ts
)
,
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
), cpu_time AS (
  SELECT window_id, ucpu, SUM(dur_ns) AS sched_covered_ns,
    SUM(CASE WHEN is_idle = 0 THEN dur_ns ELSE 0 END) AS busy_ns,
    SUM(CASE WHEN is_idle = 1 THEN dur_ns ELSE 0 END) AS idle_ns,
    SUM(CASE WHEN is_idle IS NULL THEN dur_ns ELSE 0 END) AS idle_identity_unknown_ns,
    SUM(CASE WHEN is_unfinished THEN dur_ns ELSE 0 END) AS unfinished_sched_ns
  FROM system_sched_spans GROUP BY window_id, ucpu
)
SELECT w.window_id, w.window_start_ts, w.window_end_ts,
  c.machine_id, c.core_type, c.topology_source,
  GROUP_CONCAT(c.ucpu) AS ucpus, COUNT(*) AS cpu_count,
  COUNT(*) * (w.window_end_ts - w.window_start_ts) AS cluster_window_ns,
  ROUND(100.0 * SUM(s.busy_ns) /
    NULLIF(COUNT(*) * (w.window_end_ts - w.window_start_ts), 0), 1) AS utilization_pct,
  ROUND(SUM(s.sched_covered_ns) / 1e6, 2) AS total_time_ms,
  COALESCE(SUM(s.sched_covered_ns), 0) AS sched_covered_ns,
  SUM(s.busy_ns) AS busy_ns, SUM(s.idle_ns) AS idle_ns,
  SUM(s.idle_identity_unknown_ns) AS idle_identity_unknown_ns,
  SUM(s.unfinished_sched_ns) AS unfinished_sched_ns,
  100.0 * COALESCE(SUM(s.sched_covered_ns), 0) /
    NULLIF(COUNT(*) * (w.window_end_ts - w.window_start_ts), 0) AS sched_coverage_pct,
  CASE WHEN SUM(s.sched_covered_ns) IS NULL THEN 'unavailable'
    WHEN SUM(s.sched_covered_ns) > COUNT(*) * (w.window_end_ts - w.window_start_ts) THEN 'unsupported'
    WHEN SUM(s.idle_identity_unknown_ns) > 0
      OR SUM(s.sched_covered_ns) < COUNT(*) * (w.window_end_ts - w.window_start_ts) THEN 'partial'
    ELSE 'observed' END AS sched_evidence,
  'known_nonidle_duration_over_cpu_count_times_window;_partial_coverage_is_lower_bound' AS utilization_basis
FROM system_windows w CROSS JOIN system_cpu_topology c
LEFT JOIN cpu_time s ON s.window_id = w.window_id AND s.ucpu = c.ucpu
WHERE w.window_end_ts > w.window_start_ts
GROUP BY w.window_id, c.machine_id, c.core_type, c.topology_source
ORDER BY c.machine_id, c.core_type
