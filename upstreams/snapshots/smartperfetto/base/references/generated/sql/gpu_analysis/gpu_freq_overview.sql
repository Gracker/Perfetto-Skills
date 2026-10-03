-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: ccca4067c8ee136de6c5a431984bc78be6e76efd3e44164776f7513e754a9c90

-- MHz from fragments/gpu_frequency_intervals.sql. Average and range are of
-- the time the GPU ran; max_freq_time_pct and off_pct are of all observed
-- time, so time powered off counts as not at the top frequency.
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
-- fragments/gpu_frequency_window.sql, listed before this fragment. One row
-- per GPU over the window: observed time split into running, off and
-- out-of-domain time, and the running frequencies (MHz) weighted by time.
-- A share of running time and a share of observed time are different
-- numbers; a consumer names which one it reports.
gpu_frequency_summary AS (
  SELECT
    gpu_id,
    SUM(dur) AS observed_ns,
    SUM(CASE WHEN running_mhz IS NOT NULL THEN dur ELSE 0 END) AS running_ns,
    SUM(CASE WHEN is_off THEN dur ELSE 0 END) AS off_ns,
    SUM(CASE WHEN freq_mhz IS NULL THEN dur ELSE 0 END) AS out_of_domain_ns,
    SUM(running_mhz * dur) / NULLIF(SUM(CASE WHEN running_mhz IS NOT NULL THEN dur END), 0) AS avg_running_mhz,
    MAX(running_mhz) AS max_running_mhz,
    MIN(running_mhz) AS min_running_mhz,
    COUNT(DISTINCT running_mhz) AS running_levels,
    SUM(is_running_change) AS running_change_count
  FROM gpu_frequency_window
  GROUP BY gpu_id
)
,
overview AS (
  SELECT
    s.*,
    100.0 * COALESCE((
      SELECT SUM(w.dur) FROM gpu_frequency_window w
      WHERE w.gpu_id = s.gpu_id AND w.running_mhz = s.max_running_mhz
    ), 0) / NULLIF(s.observed_ns, 0) AS top_pct
  FROM gpu_frequency_summary s
)
SELECT
  gpu_id,
  ROUND(avg_running_mhz, 0) as weighted_avg_freq_mhz,
  ROUND(max_running_mhz, 0) as max_freq_mhz,
  ROUND(min_running_mhz, 0) as min_freq_mhz,
  ROUND(top_pct, 1) as max_freq_time_pct,
  running_levels as freq_levels,
  running_change_count as freq_change_count,
  ROUND(100.0 * off_ns / NULLIF(observed_ns, 0), 1) as off_pct,
  ROUND(observed_ns / 1e9, 2) as total_time_sec,
  CASE
    WHEN top_pct > ${high_freq_threshold_pct|70} THEN '高负载'
    WHEN top_pct > ${mid_freq_threshold_pct|40} THEN '中负载'
    WHEN top_pct > ${low_freq_threshold_pct|10} THEN '低负载'
    ELSE '空闲'
  END as rating
FROM overview
ORDER BY gpu_id
