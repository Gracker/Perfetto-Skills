-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_system_context_in_range.skill.yaml
-- Source SHA-256: 3710a589131ec1ee6dd86475a1c8d00a5b2cc57ed4a1ccead52b2dbaeb4b050d
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
frequency AS (
  SELECT window_id, ucpu, SUM(dur_ns) AS frequency_covered_ns,
    SUM(freq_khz * 1.0 * dur_ns) / SUM(dur_ns) AS avg_freq_khz,
    MIN(freq_khz) AS min_freq_khz, MAX(freq_khz) AS observed_max_freq_khz
  FROM system_cpu_frequency_spans GROUP BY window_id, ucpu
),
running AS (
  SELECT window_id, ucpu, SUM(dur_ns) AS sched_covered_ns,
    SUM(CASE WHEN is_idle = 0 THEN dur_ns ELSE 0 END) AS busy_ns,
    SUM(CASE WHEN is_idle = 1 THEN dur_ns ELSE 0 END) AS idle_ns,
    SUM(CASE WHEN is_idle IS NULL THEN dur_ns ELSE 0 END) AS idle_identity_unknown_ns,
    SUM(CASE WHEN is_unfinished THEN dur_ns ELSE 0 END) AS unfinished_sched_ns
  FROM system_sched_spans GROUP BY window_id, ucpu
)
SELECT w.window_id, w.window_start_ts, w.window_end_ts,
  w.window_end_ts-w.window_start_ts AS window_dur_ns,
  c.ucpu, c.cpu, c.machine_id, c.cluster_id, c.capacity, c.core_type, c.topology_source,
  f.avg_freq_khz, f.min_freq_khz, f.observed_max_freq_khz,
  COALESCE(f.frequency_covered_ns, 0) AS frequency_covered_ns,
  CASE WHEN m.mapping_count != 1 THEN 'unsupported'
    WHEN f.frequency_covered_ns IS NULL THEN 'unavailable'
    WHEN f.frequency_covered_ns > w.window_end_ts-w.window_start_ts THEN 'unsupported'
    WHEN f.frequency_covered_ns < w.window_end_ts-w.window_start_ts THEN 'partial'
    ELSE 'observed' END AS frequency_evidence,
  'linux.cpu.frequency:cpu_frequency_counters' AS frequency_source,
  COALESCE(s.sched_covered_ns, 0) AS sched_covered_ns, s.busy_ns,
  s.idle_ns, s.idle_identity_unknown_ns,
  100.0*s.busy_ns/NULLIF(w.window_end_ts-w.window_start_ts,0) AS busy_pct,
  s.unfinished_sched_ns,
  CASE WHEN s.sched_covered_ns IS NULL THEN 'unavailable'
    WHEN s.sched_covered_ns > w.window_end_ts-w.window_start_ts THEN 'unsupported'
    WHEN s.idle_identity_unknown_ns > 0 THEN 'partial'
    WHEN s.sched_covered_ns < w.window_end_ts-w.window_start_ts THEN 'partial'
    ELSE 'observed' END AS sched_evidence,
  'system_context_not_causal_attribution' AS evidence_scope
FROM system_windows w CROSS JOIN system_cpu_topology c
LEFT JOIN system_frequency_cpu_mapping m ON c.ucpu=m.ucpu
LEFT JOIN frequency f ON f.window_id=w.window_id AND f.ucpu=c.ucpu
LEFT JOIN running s ON s.window_id=w.window_id AND s.ucpu=c.ucpu
WHERE w.window_end_ts > w.window_start_ts
ORDER BY w.window_id,c.ucpu
