-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_anomalous_threads_in_range.skill.yaml
-- Source SHA-256: ebd323de6763d2610995f371f900c448a892c16151ffa0bec43f440e1c702042
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

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
threshold_text AS (
  SELECT printf('sustained_pct=%s;spin_avg_slice_us=%s;spin_switches_per_s=%s;waker_per_s=%s;kernel_daemon_share_pct=%s',
    ${sustained_pct|80}, ${spin_avg_slice_us|200}, ${spin_switches_per_s|2000},
    ${waker_per_s|500}, ${kernel_daemon_share_pct|10}) AS text
),
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
window_facts AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    w.window_end_ts - w.window_start_ts AS window_dur_ns,
    (w.window_end_ts - w.window_start_ts) / 1e9 AS window_sec
  FROM system_windows w
),
busy_spans AS (
  SELECT s.window_id, s.utid, s.upid, s.dur_ns
  FROM system_sched_spans s
  WHERE COALESCE(s.is_idle, 0) = 0 AND s.dur_ns > 0
),
per_thread AS (
  SELECT window_id, utid, upid, SUM(dur_ns) AS running_ns, COUNT(*) AS sched_slice_count
  FROM busy_spans GROUP BY window_id, utid, upid
),
total_running AS (
  SELECT SUM(running_ns) AS total_running_ns FROM per_thread
),
waker_available AS (
  SELECT COUNT(*) AS n FROM thread_state
  WHERE waker_utid IS NOT NULL
    AND ts < (SELECT window_end_ts FROM window_facts)
    AND ts >= (SELECT window_start_ts FROM window_facts)
),
wakeups AS (
  SELECT waker_utid AS utid, COUNT(*) AS wakeups_sent
  FROM thread_state
  WHERE waker_utid IS NOT NULL
    AND ts < (SELECT window_end_ts FROM window_facts)
    AND ts >= (SELECT window_start_ts FROM window_facts)
  GROUP BY waker_utid
),
scored AS (
  SELECT
    wf.window_start_ts, wf.window_end_ts, wf.window_dur_ns, wf.window_sec,
    pt.upid, pt.utid,
    COALESCE(p.name, '') AS process_name,
    COALESCE(th.name, '') AS thread_name,
    COALESCE(ac.actor_class, 'kernel') AS actor_class,
    pt.running_ns, pt.sched_slice_count,
    100.0 * pt.running_ns / NULLIF(wf.window_dur_ns, 0) AS running_pct_of_window,
    pt.running_ns / 1000.0 / NULLIF(pt.sched_slice_count, 0) AS avg_slice_us,
    pt.sched_slice_count / NULLIF(wf.window_sec, 0) AS switches_per_s,
    CASE WHEN (SELECT n FROM waker_available) > 0
      THEN COALESCE(wk.wakeups_sent, 0) / NULLIF(wf.window_sec, 0) END AS wakeups_sent_per_s,
    CASE WHEN (SELECT n FROM waker_available) > 0 THEN 'observed'
      ELSE 'unavailable_no_waker_utid_in_window' END AS waker_evidence,
    100.0 * pt.running_ns / NULLIF((SELECT total_running_ns FROM total_running), 0) AS share_of_running_pct
  FROM per_thread pt
  CROSS JOIN window_facts wf
  LEFT JOIN thread th ON th.utid = pt.utid
  LEFT JOIN process p ON p.upid = pt.upid
  LEFT JOIN actor_class_by_upid ac ON ac.upid = pt.upid
  LEFT JOIN wakeups wk ON wk.utid = pt.utid
),
flagged AS (
  SELECT s.*,
    CASE WHEN s.running_pct_of_window >= ${sustained_pct|80} THEN 1 ELSE 0 END AS sustained_runner,
    CASE WHEN s.avg_slice_us < ${spin_avg_slice_us|200}
      AND s.switches_per_s > ${spin_switches_per_s|2000} THEN 1 ELSE 0 END AS spin_like,
    CASE WHEN s.actor_class = 'kernel'
      AND s.share_of_running_pct >= ${kernel_daemon_share_pct|10} THEN 1 ELSE 0 END AS kernel_daemon_heavy,
    CASE WHEN s.wakeups_sent_per_s > ${waker_per_s|500} THEN 1 ELSE 0 END AS waker_storm
  FROM scored s
),
ranked AS (
  SELECT f.window_start_ts, f.window_end_ts, f.window_dur_ns,
    f.upid, f.utid, f.process_name, f.thread_name, f.actor_class,
    f.running_ns,
    ROUND(f.running_pct_of_window, 2) AS running_pct_of_window,
    f.sched_slice_count,
    ROUND(f.avg_slice_us, 1) AS avg_slice_us,
    ROUND(f.switches_per_s, 1) AS switches_per_s,
    ROUND(f.wakeups_sent_per_s, 1) AS wakeups_sent_per_s,
    f.waker_evidence,
    f.sustained_runner, f.spin_like, f.kernel_daemon_heavy, f.waker_storm,
    f.sustained_runner + f.spin_like + f.kernel_daemon_heavy + f.waker_storm AS signal_count,
    ROUND(f.share_of_running_pct, 2) AS share_of_running_pct,
    (SELECT text FROM threshold_text) AS thresholds,
    'flagged' AS status,
    'observation_not_causal' AS evidence_scope
  FROM flagged f
  WHERE f.sustained_runner + f.spin_like + f.kernel_daemon_heavy + f.waker_storm > 0
  ORDER BY signal_count DESC, f.running_ns DESC
  LIMIT ${top_n|30}
)
SELECT * FROM ranked
UNION ALL
SELECT
  (SELECT window_start_ts FROM window_facts), (SELECT window_end_ts FROM window_facts),
  (SELECT window_dur_ns FROM window_facts),
  NULL, NULL, '', '', 'none',
  NULL, NULL, NULL, NULL, NULL, NULL,
  (SELECT CASE WHEN n > 0 THEN 'observed' ELSE 'unavailable_no_waker_utid_in_window' END FROM waker_available),
  NULL, NULL, NULL, NULL, 0, NULL,
  (SELECT text FROM threshold_text),
  CASE WHEN (SELECT COUNT(*) FROM per_thread) = 0
    THEN 'no_sched_data_in_window'
    ELSE 'no_thread_matched_declared_thresholds' END,
  'observation_not_causal'
WHERE NOT EXISTS (SELECT 1 FROM ranked)
