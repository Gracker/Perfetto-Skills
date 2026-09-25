-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
-- Source SHA-256: b24f5a2e47a5f0d7ae34fcfc86c1a7f58e53b09f13f6b5e6e36b5a998da2053c
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

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
), track_identity AS (
  SELECT t.id AS track_id, t.cpu, t.machine_id,
    COUNT(ct.ucpu) AS cpu_mapping_count,
    CASE WHEN COUNT(ct.ucpu) = 1 THEN MIN(ct.ucpu) END AS ucpu,
    CASE WHEN COUNT(ct.ucpu) = 1 THEN MIN(ct.core_type) ELSE 'unknown' END AS core_type,
    CASE WHEN COUNT(ct.ucpu) = 1 THEN MIN(ct.topology_source) ELSE 'cpu_identity_unavailable' END AS topology_source
  FROM cpu_counter_track t LEFT JOIN system_cpu_topology ct
    ON ct.cpu = t.cpu AND ct.machine_id IS t.machine_id
  WHERE t.name = 'runqueue_length'
  GROUP BY t.id, t.cpu, t.machine_id
)
SELECT
  t.track_id, t.cpu, t.ucpu, t.machine_id, t.core_type, t.topology_source, t.cpu_mapping_count,
  ROUND(AVG(c.value), 2) as avg_runqueue,
  MAX(c.value) as max_runqueue,
  COUNT(*) AS sample_count,
  MIN(c.ts) AS first_sample_ts, MAX(c.ts) AS last_sample_ts,
  'arithmetic_sample_mean_not_time_weighted' AS aggregation_basis
FROM counter c
JOIN track_identity t ON c.track_id = t.track_id
WHERE c.ts >= ${start_ts}
  AND c.ts < ${end_ts}
GROUP BY t.track_id
ORDER BY t.machine_id, t.cpu, t.track_id
