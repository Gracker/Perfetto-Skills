-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thread_cpu_placement_timeline.skill.yaml
-- Source SHA-256: 34281aa6d8fb63c02afd70d429360ea02b61774c67d9a554d7a96c0ec77facfc
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
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
system_target_threads AS (
  SELECT w.window_id, p.upid, t.utid,
    CASE WHEN t.tid = p.pid THEN 'main' ELSE 'target' END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p
  JOIN thread t ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (${utid} IS NULL OR t.utid = ${utid})
)
SELECT s.window_id,s.window_start_ts,s.window_end_ts,s.window_end_ts-s.window_start_ts AS window_dur_ns,
  tt.upid,p.pid,p.name AS process_name,tt.utid,t.tid,t.name AS thread_name,tt.role,
  s.sched_id,s.raw_start_ts,s.raw_dur,s.raw_end_ts,s.clipped_start_ts,s.clipped_end_ts,s.dur_ns,
  s.is_unfinished,s.left_censored,s.right_censored,s.ucpu,s.cpu,s.machine_id,s.cluster_id,s.capacity,
  s.core_type,s.topology_source,s.priority,s.end_state,
  'not_recorded_in_sched_slice' AS scheduling_policy_evidence,
  CASE WHEN s.topology_source='capacity_uniform_no_big_little' THEN 'homogeneous_big_little_not_applicable'
    WHEN s.core_type='unknown' THEN 'unknown_topology' ELSE 'heterogeneous_capacity' END AS placement_mode,
  CASE WHEN s.topology_source='capacity_uniform_no_big_little' THEN 'observed'
    WHEN s.core_type='unknown' THEN 'partial' ELSE 'observed' END AS placement_evidence,
  'placement_observation_not_affinity_configuration' AS evidence_scope
FROM system_sched_spans s JOIN system_target_threads tt
  ON tt.window_id=s.window_id AND tt.utid=s.utid AND tt.upid=s.upid
JOIN thread t ON tt.utid=t.utid JOIN process p ON p.upid=tt.upid
ORDER BY s.window_id,s.raw_start_ts,s.sched_id
