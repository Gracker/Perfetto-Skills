-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_workload_attribution_in_range.skill.yaml
-- Source SHA-256: deda79ad447ced6323b09d92a57c1031fe27378e197e1e8cb0845a30efca29e8
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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- process-identity: label-only
-- (identityGate: its name comparisons label actors, they select no target
-- process, so they do not make a consuming Skill verify process identity.)

-- Inputs: ${package}, ${process_name} (string parameters; empty when no
-- target process was selected). Requires the android.process_metadata
-- stdlib module.
--
-- One process-level actor label shared by every workload / anomaly Skill so
-- the App-vs-system split is defined once. Threads with no process (no upid)
-- get no row here; consumers COALESCE the missing label to 'kernel'.
actor_class_basis AS (
  SELECT 'target=param_name_match;kernel=android_process_metadata.is_kernel_task;app=process.uid>=10000' AS actor_class_basis
),
actor_class_by_upid AS (
  SELECT p.upid,
    CASE
      WHEN ('${package}' != '' AND (p.name = '${package}' OR p.name GLOB '${package}:*'))
        OR ('${process_name}' != '' AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
        THEN 'target_app'
      WHEN COALESCE(pm.is_kernel_task, 0) = 1 AND COALESCE(p.pid, 0) > 1 THEN 'kernel'
      WHEN COALESCE(p.uid, -1) >= 10000 THEN 'other_app'
      WHEN p.name IS NOT NULL THEN 'system_service'
      ELSE 'unknown'
    END AS actor_class
  FROM process p
  LEFT JOIN android_process_metadata pm ON pm.upid = p.upid
)
,
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
window_facts AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    w.window_end_ts - w.window_start_ts AS window_dur_ns,
    (SELECT COUNT(*) FROM system_cpu_topology) AS cpu_count
  FROM system_windows w
),
busy_spans AS (
  SELECT s.window_id, s.utid, s.upid, s.core_type, s.dur_ns, s.is_unfinished
  FROM system_sched_spans s
  WHERE COALESCE(s.is_idle, 0) = 0 AND s.dur_ns > 0
),
labelled AS (
  SELECT b.*,
    COALESCE(ac.actor_class, 'kernel') AS actor_class
  FROM busy_spans b
  LEFT JOIN actor_class_by_upid ac ON ac.upid = b.upid
),
by_actor AS (
  SELECT 'actor_class' AS breakdown_kind, actor_class AS breakdown_key,
    SUM(dur_ns) AS running_ns, COUNT(DISTINCT utid) AS thread_count,
    MAX(CASE WHEN is_unfinished THEN 1 ELSE 0 END) AS has_unfinished,
    'window_dur_ns * cpu_count' AS denominator_basis,
    SUM(dur_ns) * 1.0 / NULLIF((SELECT window_dur_ns * cpu_count FROM window_facts), 0) AS ratio
  FROM labelled GROUP BY actor_class
),
core_counts AS (
  SELECT core_type, COUNT(*) AS cores FROM system_cpu_topology GROUP BY core_type
),
by_core AS (
  SELECT 'core_type' AS breakdown_kind, l.core_type AS breakdown_key,
    SUM(l.dur_ns) AS running_ns, COUNT(DISTINCT l.utid) AS thread_count,
    MAX(CASE WHEN l.is_unfinished THEN 1 ELSE 0 END) AS has_unfinished,
    'window_dur_ns * cores_of_this_core_type' AS denominator_basis,
    SUM(l.dur_ns) * 1.0 / NULLIF((SELECT window_dur_ns FROM window_facts) * COALESCE(cc.cores, 0), 0) AS ratio
  FROM labelled l LEFT JOIN core_counts cc ON cc.core_type = l.core_type
  GROUP BY l.core_type, cc.cores
),
unioned AS (
  SELECT * FROM by_actor UNION ALL SELECT * FROM by_core
)
SELECT wf.window_start_ts, wf.window_end_ts, wf.window_dur_ns,
  u.breakdown_kind, u.breakdown_key, u.running_ns,
  ROUND(100.0 * u.ratio, 2) AS busy_pct,
  u.thread_count, u.denominator_basis,
  CASE WHEN u.has_unfinished = 1 THEN 'partial' ELSE 'observed' END AS sched_evidence,
  'observation_not_causal' AS evidence_scope
FROM unioned u CROSS JOIN window_facts wf
ORDER BY u.breakdown_kind, u.running_ns DESC
