-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_limit_timeline.skill.yaml
-- Source SHA-256: 9ca20ae0bd75e18a790d8f725bc86549da9ef82647525a0180194ab11908877b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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
-- Requires fragments/system_sched_spans.sql to be injected FIRST: policy
-- leader CPUs are classified through its system_cpu_topology, so every CPU
-- Skill shares one big/little definition.
--
-- Direct cpufreq policy limit evidence from the typed tracks emitted by the
-- ftrace event power/cpu_frequency_limits. `cpu_counter_track.cpu` carries the
-- cpufreq policy leader CPU, not every CPU governed by that policy.
--
-- A track's first sample is the first CHANGE observed, so the state before it
-- is unknown; it is never proof that the policy was unlimited. The per-policy
-- reference is the maximum max-limit observed in this trace and is explicitly
-- labelled `observed_max_limit_in_trace_not_hardware_max`: it cannot establish
-- the hardware or OPP-table maximum.
system_cpu_freq_limit_raw AS (
  SELECT t.id AS track_id, t.cpu AS policy_cpu,
    CASE WHEN t.type='cpu_max_frequency_limit' THEN 'max' ELSE 'min' END AS kind,
    c.id AS counter_id, c.ts, CAST(c.value AS INTEGER) AS limit_khz,
    CAST(LAG(c.value) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS INTEGER) AS prev_limit_khz,
    LEAD(c.ts) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS next_ts
  FROM cpu_counter_track t JOIN counter c ON c.track_id = t.id
  WHERE t.type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')
),
system_cpu_freq_limit_reference AS (
  SELECT policy_cpu,
    MAX(CASE WHEN kind='max' THEN limit_khz END) AS reference_max_limit_khz,
    MIN(CASE WHEN kind='max' THEN ts END) AS first_max_sample_ts,
    MAX(CASE WHEN kind='max' THEN ts END) AS last_max_sample_ts,
    'observed_max_limit_in_trace_not_hardware_max' AS reference_basis
  FROM system_cpu_freq_limit_raw
  GROUP BY policy_cpu
),
system_cpu_freq_limit_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    r.track_id, r.policy_cpu, r.kind, r.counter_id,
    r.limit_khz, r.prev_limit_khz,
    tp.ucpu, tp.machine_id, tp.capacity,
    COALESCE(tp.core_type, 'unknown') AS core_type,
    COALESCE(tp.topology_source, 'cpu_identity_unavailable') AS topology_source,
    r.ts AS raw_start_ts,
    COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)) AS raw_end_ts,
    MAX(r.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)), w.window_end_ts) AS clipped_end_ts,
    MIN(COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)), w.window_end_ts)
      - MAX(r.ts, w.window_start_ts) AS dur_ns,
    r.ts < w.window_start_ts AS left_censored,
    r.next_ts IS NULL OR r.next_ts > w.window_end_ts AS right_censored,
    r.ts = ref.first_max_sample_ts AND r.kind='max' AS is_first_max_sample,
    r.ts = ref.last_max_sample_ts AND r.kind='max' AS is_last_max_sample,
    ref.reference_max_limit_khz, ref.reference_basis,
    'ftrace:power/cpu_frequency_limits' AS limit_source
  FROM system_windows w
  JOIN system_cpu_freq_limit_raw r
    ON r.ts < w.window_end_ts
    AND COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)) > w.window_start_ts
  LEFT JOIN system_cpu_freq_limit_reference ref ON ref.policy_cpu = r.policy_cpu
  -- The event names the leader by its local cpu number. When several machines
  -- share that number the identity is ambiguous, so no topology is attached.
  LEFT JOIN system_cpu_topology tp ON tp.cpu = r.policy_cpu
    AND (SELECT COUNT(*) FROM cpu c2 WHERE c2.cpu = r.policy_cpu) = 1
  WHERE w.window_end_ts > w.window_start_ts
)
,
data_start AS (
  SELECT MIN(x) AS ts FROM (
    SELECT MIN(ts) AS x FROM sched_slice
    UNION ALL
    SELECT MIN(c.ts) FROM counter c JOIN cpu_counter_track t ON c.track_id = t.id
      WHERE t.type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')
  )
),
system_windows AS (
  SELECT 0 AS window_id,
    COALESCE(${start_ts}, (SELECT ts FROM data_start), (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
)
SELECT s.raw_start_ts AS ts, s.policy_cpu, s.core_type, s.kind,
  s.prev_limit_khz, s.limit_khz,
  s.limit_khz - s.prev_limit_khz AS delta_khz,
  CASE
    WHEN s.prev_limit_khz IS NULL THEN 'first_observed_sample'
    WHEN s.kind = 'max' AND s.limit_khz < s.prev_limit_khz THEN 'tightened'
    WHEN s.kind = 'max' AND s.limit_khz > s.prev_limit_khz THEN 'relaxed'
    WHEN s.kind = 'min' AND s.limit_khz > s.prev_limit_khz THEN 'floor_raised'
    WHEN s.kind = 'min' AND s.limit_khz < s.prev_limit_khz THEN 'floor_lowered'
    ELSE 'unchanged'
  END AS direction,
  s.dur_ns, s.reference_max_limit_khz, s.limit_source,
  'observation_not_causal' AS evidence_scope
FROM system_cpu_freq_limit_spans s
WHERE s.raw_start_ts >= s.window_start_ts AND s.raw_start_ts < s.window_end_ts
ORDER BY s.raw_start_ts, s.policy_cpu, s.kind DESC
