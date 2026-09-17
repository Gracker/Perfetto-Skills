-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_cpu_placement_timeline.skill.yaml
-- Source SHA-256: df62a33d3357a3f835c86fe807b64725bb4ce7129067c81f63799ccfa838aef3
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

WITH RECURSIVE
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
system_windows AS (SELECT 0 AS window_id,
  COALESCE(${start_ts},(SELECT start_ts FROM trace_bounds)) AS window_start_ts,
  COALESCE(${end_ts},(SELECT end_ts FROM trace_bounds)) AS window_end_ts),
system_target_threads AS (
  SELECT w.window_id,p.upid,t.utid,CASE WHEN t.tid=p.pid THEN 'main' ELSE 'target' END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p JOIN thread t ON t.upid=p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
),
bucket_size AS (SELECT MAX(${bucket_ms|50}*1000000,(${end_ts}-${start_ts})/30,1) AS bucket_ns),
buckets AS (
 SELECT 0 AS bucket_idx,${start_ts} AS bucket_start,MIN(${start_ts}+(SELECT bucket_ns FROM bucket_size),${end_ts}) AS bucket_end
 WHERE ${end_ts}>${start_ts}
 UNION ALL
 SELECT bucket_idx+1,bucket_end,MIN(bucket_end+(SELECT bucket_ns FROM bucket_size),${end_ts})
 FROM buckets WHERE bucket_end<${end_ts} AND bucket_idx<29
),
main_targets AS (SELECT tt.* FROM system_target_threads tt WHERE role='main'),
segments AS (
 SELECT s.* FROM system_sched_spans s JOIN main_targets tt ON tt.utid=s.utid AND tt.upid=s.upid AND tt.window_id=s.window_id
)
SELECT tt.upid,tt.utid,b.bucket_idx,b.bucket_start AS window_start_ts,b.bucket_end AS window_end_ts,
 (b.bucket_start-${start_ts})/1e6 AS bucket_offset_ms,
 SUM(CASE WHEN s.core_type IN ('prime','big','medium') THEN MIN(s.clipped_end_ts,b.bucket_end)-MAX(s.clipped_start_ts,b.bucket_start) ELSE 0 END)/1e6 AS big_core_ms,
 SUM(CASE WHEN s.core_type='little' THEN MIN(s.clipped_end_ts,b.bucket_end)-MAX(s.clipped_start_ts,b.bucket_start) ELSE 0 END)/1e6 AS little_core_ms,
 SUM(CASE WHEN s.core_type='unknown' THEN MIN(s.clipped_end_ts,b.bucket_end)-MAX(s.clipped_start_ts,b.bucket_start) ELSE 0 END)/1e6 AS unknown_core_ms,
 SUM(CASE WHEN s.core_type IN ('prime','big','medium') THEN MIN(s.clipped_end_ts,b.bucket_end)-MAX(s.clipped_start_ts,b.bucket_start) ELSE 0 END)*100.0/
   NULLIF(SUM(MIN(s.clipped_end_ts,b.bucket_end)-MAX(s.clipped_start_ts,b.bucket_start)),0) AS big_core_pct,
 GROUP_CONCAT(DISTINCT s.cpu) AS used_cpus,GROUP_CONCAT(DISTINCT s.ucpu) AS used_ucpus,
 GROUP_CONCAT(DISTINCT s.core_type) AS core_types,
 SUM(MIN(s.clipped_end_ts,b.bucket_end)-MAX(s.clipped_start_ts,b.bucket_start)) AS sched_covered_ns,
 CASE WHEN COUNT(s.sched_id)=0 THEN 'unavailable' ELSE 'observed' END AS sched_evidence
FROM buckets b CROSS JOIN main_targets tt LEFT JOIN segments s ON s.utid=tt.utid AND s.upid=tt.upid
 AND s.clipped_start_ts<b.bucket_end AND s.clipped_end_ts>b.bucket_start
GROUP BY tt.upid,tt.utid,b.bucket_idx ORDER BY tt.upid,tt.utid,b.bucket_idx
