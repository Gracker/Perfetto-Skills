-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 608783942f2db1a99117105e5d2d95faddd0b3074bd5cfdc5ad464f383ec5280

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- No input CTE. The GPU frequency of every GPU as leading intervals, one row
-- per counter sample of the trace_processor "gpufreq" track (the same input
-- and interval shape as stdlib android_gpu_frequency, which returns the raw
-- value), with the value normalized to MHz.
--
-- That track is labelled kHz, but its writers disagree: power/gpu_frequency
-- and generic GPU events write kHz, kgsl_gpu_frequency is multiplied to Hz by
-- trace_processor, and sys_stats gpufreq_mhz writes MHz to GPU 0, so one
-- track can carry two units. Each sample is read by its own magnitude, which
-- is unambiguous for a GPU clock between 10 MHz and 10 GHz:
--   0                  off: the GPU is powered down, not running slowly
--   10 <= v < 1e4      MHz
--   1e4 <= v < 1e7     kHz
--   1e7 <= v <= 1e10   Hz
--   anything else      out_of_domain, freq_mhz NULL
-- prev_freq_mhz is the normalized previous value, so a unit change is not
-- a frequency change. A consumer reports off time apart and
-- leaves it out of averages and low-frequency shares.
gpu_frequency_samples AS (
  SELECT
    c.id AS counter_id,
    c.ts,
    c.track_id,
    t.ugpu,
    t.gpu_id,
    c.value AS raw_value,
    CASE
      WHEN c.value = 0 THEN 'off'
      WHEN c.value >= 10 AND c.value < 1e4 THEN 'mhz'
      WHEN c.value >= 1e4 AND c.value < 1e7 THEN 'khz'
      WHEN c.value >= 1e7 AND c.value <= 1e10 THEN 'hz'
      ELSE 'out_of_domain'
    END AS unit_basis
  FROM counter c
  JOIN gpu_counter_track t ON t.id = c.track_id
  WHERE t.name = 'gpufreq' AND t.gpu_id IS NOT NULL
),
gpu_frequency_normalized AS (
  SELECT
    *,
    CASE unit_basis
      WHEN 'off' THEN 0.0
      WHEN 'mhz' THEN raw_value
      WHEN 'khz' THEN raw_value / 1e3
      WHEN 'hz' THEN raw_value / 1e6
    END AS freq_mhz
  FROM gpu_frequency_samples
),
gpu_frequency_intervals AS (
  SELECT
    counter_id,
    ts,
    COALESCE(LEAD(ts) OVER w, trace_end()) - ts AS dur,
    track_id,
    ugpu,
    gpu_id,
    freq_mhz,
    unit_basis = 'off' AS is_off,
    unit_basis,
    LAG(freq_mhz) OVER w AS prev_freq_mhz
  FROM gpu_frequency_normalized
  WINDOW w AS (PARTITION BY track_id ORDER BY ts, counter_id)
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: fragments/gpu_frequency_intervals.sql, listed before this fragment;
-- the step parameters start_ts and end_ts (either may be NULL). The GPU
-- frequency intervals that overlap [start_ts, end_ts), clipped to it, so a
-- level held from before the window counts only for its time inside.
-- running_mhz is the frequency while the GPU runs (NULL when off or
-- unreadable). is_running_change marks a change between two running
-- frequencies whose sample was taken inside the window.
gpu_frequency_window AS (
  SELECT
    counter_id,
    ugpu,
    gpu_id,
    freq_mhz,
    is_off,
    prev_freq_mhz,
    CASE WHEN freq_mhz > 0 THEN freq_mhz END AS running_mhz,
    COALESCE((${start_ts} IS NULL OR ts >= ${start_ts}) AND freq_mhz > 0
      AND prev_freq_mhz > 0 AND freq_mhz != prev_freq_mhz, 0) AS is_running_change,
    MAX(ts, COALESCE(${start_ts}, ts)) AS ts,
    MIN(ts + dur, COALESCE(${end_ts}, ts + dur)) - MAX(ts, COALESCE(${start_ts}, ts)) AS dur
  FROM gpu_frequency_intervals
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ${end_ts} IS NULL OR ${start_ts} < ${end_ts})
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: fragments/gpu_frequency_intervals.sql and
-- fragments/gpu_frequency_window.sql, listed before this fragment; the step
-- parameter ugpu (NULL for every GPU). The readable frequency intervals of
-- each GPU keyed by ugpu, for interval joins against GPU activity: running
-- frequencies in MHz and 0 while the GPU is off. gpu_ugpu_fmax is the top
-- running frequency of each GPU in the window.
gpu_ugpu_frequency AS (
  SELECT counter_id AS id, ts, dur, ugpu, freq_mhz
  FROM gpu_frequency_window
  WHERE freq_mhz IS NOT NULL
    AND (${ugpu} IS NULL OR ugpu = ${ugpu})
),
gpu_ugpu_fmax AS (
  SELECT ugpu, MAX(freq_mhz) AS fmax_mhz
  FROM gpu_ugpu_frequency
  WHERE freq_mhz > 0
  GROUP BY ugpu
)
,
params AS (
  SELECT
    COALESCE(${target_freq_ratio|0.9}, 0.9) AS target_ratio,
    MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 200) AS max_rows
),
-- The clock at each busy edge, 0 when the GPU was off: a cold start
-- from off is the commonest ramp and stays in.
edges AS (
  SELECT
    b.ugpu,
    b.ts AS edge_ts,
    b.te AS busy_end,
    b.ts - LAG(b.te) OVER (PARTITION BY b.ugpu ORDER BY b.ts) AS idle_gap_ns,
    (
      SELECT f.freq_mhz
      FROM gpu_ugpu_frequency AS f
      WHERE f.ugpu = b.ugpu
        AND f.ts <= b.ts
        AND f.ts + f.dur > b.ts
    ) AS freq_at_edge_mhz,
    (SELECT fmax_mhz FROM gpu_ugpu_fmax WHERE ugpu = b.ugpu) AS fmax_mhz
  FROM __sp_v57_gpu_busy AS b
),
ramps AS (
  SELECT
    e.*,
    (SELECT target_ratio FROM params) * e.fmax_mhz AS target_mhz,
    (
      SELECT MIN(f.ts)
      FROM gpu_ugpu_frequency AS f
      WHERE f.ugpu = e.ugpu
        AND f.freq_mhz >= (SELECT target_ratio FROM params) * e.fmax_mhz
        AND f.ts >= e.edge_ts
        AND f.ts < e.busy_end
    ) AS reach_ts
  FROM edges AS e
)
SELECT
  r.ugpu AS gpu,
  IFNULL(g.name, 'GPU ' || r.ugpu) AS gpu_name,
  r.edge_ts - trace_start() AS edge_rel_ns,
  r.idle_gap_ns,
  ROUND(r.freq_at_edge_mhz, 0) AS freq_at_edge_mhz,
  ROUND(r.target_mhz, 0) AS target_mhz,
  IFNULL(r.reach_ts, r.busy_end) - r.edge_ts AS ramp_ns,
  CASE WHEN r.reach_ts IS NOT NULL THEN 1 ELSE 0 END AS completed
FROM ramps AS r
LEFT JOIN gpu AS g
  ON g.ugpu = r.ugpu
WHERE r.freq_at_edge_mhz < r.target_mhz
ORDER BY ramp_ns DESC
LIMIT (SELECT max_rows FROM params)
