-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: b4477788d50246d11d2483cd0837b27f8088afd90565197ab4f32613a52e680d
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
  SELECT 0 AS window_id, COALESCE(${anr_ctx.data[0].anr_ts}-${anr_ctx.data[0].timeout_ns}, (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${anr_ctx.data[0].anr_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
),cpu_activity AS (
  SELECT s.ucpu,SUM(CASE WHEN t.is_idle=0 THEN s.dur_ns ELSE 0 END) AS active_ns,
    SUM(s.dur_ns) AS covered_ns,SUM(CASE WHEN t.is_idle IS NULL THEN s.dur_ns ELSE 0 END) AS idle_identity_unknown_ns
  FROM system_sched_spans s LEFT JOIN thread t ON t.utid=s.utid GROUP BY s.ucpu
)
SELECT ct.core_type,COUNT(*) AS core_count,
  ROUND(SUM(COALESCE(a.active_ns,0))/1e6,2) AS total_active_ms,
  CASE WHEN SUM(COALESCE(a.covered_ns,0))=0 THEN NULL ELSE ROUND(100.0*SUM(a.active_ns)/NULLIF(COUNT(*)*MAX(w.window_end_ts-w.window_start_ts),0),1) END AS avg_util_pct,
  SUM(COALESCE(a.covered_ns,0)) AS sched_covered_ns,
  SUM(COALESCE(a.idle_identity_unknown_ns,0)) AS idle_identity_unknown_ns,
  CASE WHEN SUM(COALESCE(a.covered_ns,0))<COUNT(*)*MAX(w.window_end_ts-w.window_start_ts) OR SUM(COALESCE(a.idle_identity_unknown_ns,0))>0 THEN 'insufficient_coverage'
    WHEN SUM(a.active_ns)>0.9*COUNT(*)*MAX(w.window_end_ts-w.window_start_ts) THEN 'overloaded'
    WHEN SUM(a.active_ns)>0.7*COUNT(*)*MAX(w.window_end_ts-w.window_start_ts) THEN 'busy' ELSE 'normal' END AS status
FROM system_windows w CROSS JOIN system_cpu_topology ct LEFT JOIN cpu_activity a ON a.ucpu=ct.ucpu
GROUP BY ct.core_type ORDER BY ct.core_type
