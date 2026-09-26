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

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- The pinned linux.cpu.frequency relation exposes the native ucpu after a
-- machine_id + cpu join. Use that identity rather than merging cpu ordinals.
-- Zero is a recorded counter value, not missing data or proof that hardware
-- actually executed instructions at zero frequency.
system_frequency_cpu_mapping AS (
  SELECT cpu,id AS ucpu,machine_id,1 AS mapping_count FROM cpu
),
system_cpu_frequency_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    f.id AS counter_id,f.track_id,f.cpu,m.ucpu,m.machine_id,f.freq AS freq_khz,
    f.ts AS raw_start_ts, f.dur AS raw_dur,
    CASE WHEN f.dur >= 0 THEN f.ts + f.dur END AS raw_end_ts,
    MAX(f.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN f.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE f.ts + f.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN f.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE f.ts + f.dur END, w.window_end_ts) - MAX(f.ts, w.window_start_ts) AS dur_ns,
    f.dur = -1 AS is_unfinished,
    'linux.cpu.frequency:cpu_frequency_counters' AS frequency_source
  FROM system_windows w JOIN cpu_frequency_counters f
    ON f.ts < w.window_end_ts AND f.dur >= -1 AND f.dur != 0 AND f.freq >= 0
      AND CASE WHEN f.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
        ELSE f.ts + f.dur END > w.window_start_ts
  JOIN system_frequency_cpu_mapping m ON m.ucpu=f.ucpu AND m.cpu=f.cpu
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
  SELECT s.window_id, s.utid, s.upid, s.ucpu, s.core_type,
    s.clipped_start_ts, s.clipped_end_ts, s.dur_ns, s.is_unfinished
  FROM system_sched_spans s
  WHERE COALESCE(s.is_idle, 0) = 0 AND s.dur_ns > 0
),
per_thread AS (
  SELECT window_id, utid, upid,
    SUM(dur_ns) AS running_ns,
    COUNT(*) AS sched_slice_count,
    SUM(CASE WHEN core_type = 'big' THEN dur_ns ELSE 0 END) AS big_running_ns,
    SUM(CASE WHEN core_type = 'medium' THEN dur_ns ELSE 0 END) AS medium_running_ns,
    SUM(CASE WHEN core_type = 'little' THEN dur_ns ELSE 0 END) AS little_running_ns,
    SUM(CASE WHEN core_type NOT IN ('big', 'medium', 'little') THEN dur_ns ELSE 0 END) AS unknown_core_running_ns,
    SUM(CASE WHEN is_unfinished THEN dur_ns ELSE 0 END) AS unfinished_ns
  FROM busy_spans
  GROUP BY window_id, utid, upid
),
-- Explicit interval intersection between per-thread run spans and the
-- cpufreq spans of the SAME ucpu. Both inputs are non-overlapping inside
-- each ucpu partition by construction: one task runs on a CPU at a time,
-- and a cpufreq counter holds one value at a time. Each side is already
-- clipped to the window, which preserves that invariant.
-- perfetto-interval-intersect-non-overlap-proof: system_sched_spans.sql
-- (one sched_slice per ucpu at a time) and system_cpu_frequency_spans.sql
-- (cpu_frequency_counters leading intervals per ucpu).
ii_sched AS (
  SELECT s.sched_id AS id, s.clipped_start_ts AS ts, s.dur_ns AS dur, s.ucpu AS ucpu
  FROM system_sched_spans s
  WHERE COALESCE(s.is_idle, 0) = 0 AND s.dur_ns > 0 AND s.ucpu IS NOT NULL
),
ii_freq AS (
  SELECT f.counter_id AS id, f.clipped_start_ts AS ts, f.dur_ns AS dur, f.ucpu AS ucpu
  FROM system_cpu_frequency_spans f
  WHERE f.dur_ns > 0 AND f.ucpu IS NOT NULL
),
freq_work AS (
  SELECT ss.utid AS utid,
    SUM(ii.dur * 1.0 * c.value) AS work_ns_khz,
    SUM(ii.dur) AS freq_covered_ns
  FROM _interval_intersect!((ii_sched, ii_freq), (ucpu)) AS ii
  JOIN sched_slice ss ON ss.id = ii.id_0
  JOIN counter c ON c.id = ii.id_1
  GROUP BY ss.utid
),
totals AS (
  SELECT (SELECT SUM(work_ns_khz) FROM freq_work) AS total_work_ns_khz,
    (SELECT SUM(running_ns) FROM per_thread) AS total_running_ns
)
SELECT
  wf.window_id, wf.window_start_ts, wf.window_end_ts, wf.window_dur_ns,
  pt.upid, pt.utid, p.pid, th.tid,
  COALESCE(p.name, '') AS process_name,
  COALESCE(th.name, '') AS thread_name,
  COALESCE(ac.actor_class, 'kernel') AS actor_class,
  (SELECT actor_class_basis FROM actor_class_basis) AS actor_class_basis,
  pt.running_ns,
  ROUND(100.0 * pt.running_ns / NULLIF(wf.window_dur_ns * wf.cpu_count, 0), 3) AS running_pct_of_window,
  pt.big_running_ns, pt.medium_running_ns, pt.little_running_ns, pt.unknown_core_running_ns,
  ROUND(COALESCE(fw.work_ns_khz, 0) / 1e9, 1) AS freq_weighted_work_mhz_ms,
  ROUND(100.0 * COALESCE(fw.work_ns_khz, 0) / NULLIF((SELECT total_work_ns_khz FROM totals), 0), 2) AS share_of_total_work_pct,
  pt.sched_slice_count,
  COALESCE(fw.freq_covered_ns, 0) AS freq_covered_ns,
  CASE
    WHEN fw.freq_covered_ns IS NULL THEN 'unavailable'
    WHEN fw.freq_covered_ns < pt.running_ns THEN 'partial'
    ELSE 'observed'
  END AS frequency_evidence,
  CASE WHEN pt.unfinished_ns > 0 THEN 'partial' ELSE 'observed' END AS sched_evidence,
  wf.cpu_count,
  wf.window_dur_ns * wf.cpu_count AS window_capacity_ns,
  'running_pct_of_window = running_ns / (window_dur_ns * cpu_count)' AS normalization_basis,
  'observation_not_causal' AS evidence_scope
FROM per_thread pt
CROSS JOIN window_facts wf
LEFT JOIN freq_work fw ON fw.utid = pt.utid
LEFT JOIN thread th ON th.utid = pt.utid
LEFT JOIN process p ON p.upid = pt.upid
LEFT JOIN actor_class_by_upid ac ON ac.upid = pt.upid
ORDER BY COALESCE(fw.work_ns_khz, 0) DESC, pt.running_ns DESC
LIMIT ${top_n|30}
