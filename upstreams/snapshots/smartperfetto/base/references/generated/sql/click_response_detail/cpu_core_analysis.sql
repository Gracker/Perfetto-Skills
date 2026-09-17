-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: e6caf5c56483f80b2e80c360f82ad97098e9d0865e1914f3c4c3d5c772e6c4ab
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
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
  SELECT 0 AS window_id, COALESCE(${event_ts}, (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${event_end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
),system_target_threads AS (
  SELECT w.window_id,p.upid,t.utid,CASE WHEN t.tid = p.pid THEN 'MainThread' ELSE t.name END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p JOIN thread t ON t.upid=p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR p.name='${process_name}' OR p.name GLOB '${process_name}:*') AND (t.tid=p.pid)
),scene_sched AS (
  SELECT s.* FROM system_sched_spans s JOIN system_target_threads t ON t.window_id=s.window_id AND t.utid=s.utid AND t.upid=s.upid
)
SELECT upid,utid,'MainThread' AS thread_type,
  ROUND(SUM(CASE WHEN core_type IN ('prime','big','medium') THEN dur_ns ELSE 0 END)/1e6,2) AS big_core_ms,
  ROUND(SUM(CASE WHEN core_type='little' THEN dur_ns ELSE 0 END)/1e6,2) AS little_core_ms,
  ROUND(SUM(CASE WHEN core_type='unknown' THEN dur_ns ELSE 0 END)/1e6,2) AS unknown_running_ms,
  ROUND(SUM(dur_ns)/1e6,2) AS total_running_ms,
  ROUND(100.0*SUM(CASE WHEN core_type IN ('prime','big','medium') THEN dur_ns ELSE 0 END)/NULLIF(SUM(dur_ns),0),1) AS big_core_pct,
  ROUND(100.0*SUM(CASE WHEN core_type='little' THEN dur_ns ELSE 0 END)/NULLIF(SUM(dur_ns),0),1) AS little_core_pct,
  ROUND(100.0*SUM(dur_ns)/NULLIF(MAX(window_end_ts-window_start_ts),0),1) AS running_pct,
  GROUP_CONCAT(DISTINCT cpu) AS used_cpus,GROUP_CONCAT(DISTINCT ucpu) AS used_ucpus,GROUP_CONCAT(DISTINCT topology_source) AS classify_method,
  MIN(priority) AS priority_min,MAX(priority) AS priority_max,'not_recorded_in_sched_slice' AS scheduling_policy_evidence
FROM scene_sched GROUP BY window_id,upid,utid
