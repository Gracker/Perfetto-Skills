-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 337f07b019184e56d2cbd55423b8bdf1d62ee20eb90821ab2d0791340050512f
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

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
  SELECT 0 AS window_id, COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
),freq_events AS (
  SELECT f.*,COALESCE(ct.core_type,'unknown') AS core_type,
    COALESCE(ct.topology_source,'cpu_identity_unavailable') AS topology_source,
    LAG(f.freq_khz) OVER (PARTITION BY f.window_id,f.ucpu ORDER BY f.raw_start_ts,f.counter_id) AS prev_freq_khz
  FROM system_cpu_frequency_spans f LEFT JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
),
changes AS (
  SELECT * FROM freq_events
  WHERE raw_start_ts>=window_start_ts AND raw_start_ts<window_end_ts
    AND (prev_freq_khz IS NULL OR freq_khz!=prev_freq_khz)
)
SELECT printf('%d',raw_start_ts) AS ts,
  ROUND((raw_start_ts-window_start_ts)/1e6,2) AS relative_ms,
  cpu,ucpu,counter_id,track_id,core_type,topology_source,
  ROUND(freq_khz/1000,0) AS freq_mhz,ROUND(prev_freq_khz/1000,0) AS prev_freq_mhz,
  CASE WHEN prev_freq_khz IS NULL THEN 'unknown'
    WHEN freq_khz>prev_freq_khz THEN 'up' WHEN freq_khz<prev_freq_khz THEN 'down' ELSE 'stable' END AS change_direction,
  COUNT(*) OVER () AS total_change_count,
  'recorded_counter_events_not_residence_average' AS evidence_scope
FROM changes ORDER BY raw_start_ts,ucpu,counter_id LIMIT 50
