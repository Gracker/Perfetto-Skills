-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
-- Source SHA-256: 1b8c48740c33db268d4dd30f2d4e9d0bdcb254f3439852bbaaec2ff0a373ba48
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
), runs AS (
  SELECT
    s.id AS sched_id, s.ts, s.dur, s.utid, s.ucpu,
    ct.ucpu AS mapped_ucpu, ct.machine_id, ct.cluster_id, ct.core_type,
    LAG(s.ucpu) OVER ordered_runs AS prev_ucpu,
    LAG(ct.ucpu) OVER ordered_runs AS prev_mapped_ucpu,
    LAG(ct.machine_id) OVER ordered_runs AS prev_machine_id,
    LAG(ct.cluster_id) OVER ordered_runs AS prev_cluster_id,
    LAG(ct.core_type) OVER ordered_runs AS prev_core_type,
    LAG(CASE WHEN s.dur >= 0 THEN s.ts + s.dur END) OVER ordered_runs AS prev_end_ts
  FROM sched_slice s JOIN thread t ON t.utid = s.utid AND t.is_idle = 0
  LEFT JOIN system_cpu_topology ct ON ct.ucpu = s.ucpu
  WHERE s.ts < ${end_ts} AND s.dur >= -1 AND s.dur != 0
  WINDOW ordered_runs AS (PARTITION BY s.utid ORDER BY s.ts, s.id)
), transitions AS (
  SELECT * FROM runs WHERE ts >= ${start_ts} AND ts < ${end_ts}
    AND prev_ucpu IS NOT NULL AND ucpu != prev_ucpu
), migrations AS (
  SELECT * FROM transitions WHERE mapped_ucpu IS NOT NULL AND prev_mapped_ucpu IS NOT NULL
    AND machine_id IS prev_machine_id AND prev_end_ts <= ts
)
SELECT
  COUNT(*) as migration_count,
  COALESCE(SUM(CASE WHEN cluster_id IS NOT NULL AND prev_cluster_id IS NOT NULL
    AND cluster_id != prev_cluster_id THEN 1 ELSE 0 END), 0) AS cross_cluster_migrations,
  COALESCE(SUM(CASE WHEN (prev_core_type = 'little' AND core_type IN ('medium','big','prime'))
    OR (core_type = 'little' AND prev_core_type IN ('medium','big','prime')) THEN 1 ELSE 0 END), 0) AS little_big_group_migrations,
  (SELECT COUNT(*) FROM runs WHERE ts >= ${start_ts} AND ts < ${end_ts}) AS observed_run_count,
  (SELECT COUNT(*) FROM transitions) - COUNT(*) AS unresolved_transition_count,
  CASE WHEN NOT EXISTS(SELECT 1 FROM runs WHERE ts >= ${start_ts} AND ts < ${end_ts}) THEN 'no_observed_runs'
    WHEN (SELECT COUNT(*) FROM transitions) > COUNT(*) THEN 'unresolved_transitions'
    ELSE 'observed_runs_only' END AS migration_coverage_status,
  'native_ucpu_same_machine_nonoverlapping_runs;_cluster_id_for_cross_cluster;_medium_in_big_group;_not_affinity_or_cache_miss_proof' AS migration_evidence
FROM migrations
