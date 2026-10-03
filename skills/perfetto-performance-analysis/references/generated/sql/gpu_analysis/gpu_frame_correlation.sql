-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 1782c39f5ca4ce044bf815ac7ed529e2509316b08ab38f26baaab7ce64fce6bb

-- Each frame against the lowest-numbered GPU: the running frequency
-- weighted by time inside the frame, leaving out time the GPU was off.
-- A GPU often powers up after a frame starts, so a frame whose interval
-- holds no running time is counted, not dropped, and has no frequency.
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
gpu AS MATERIALIZED (
  SELECT ts, dur, freq_mhz, gpu_id
  FROM gpu_frequency_intervals
  WHERE freq_mhz > 0
    AND gpu_id = (SELECT MIN(gpu_id) FROM gpu_frequency_intervals)
),
frames AS (
  SELECT f.id, f.ts, f.dur, COALESCE(f.jank_type, 'None') as jank_type
  FROM actual_frame_timeline_slice f
  LEFT JOIN process p ON f.upid = p.upid
  WHERE f.dur > 0
    AND ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR f.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR f.ts < ${end_ts})
    AND COALESCE(f.display_frame_token, f.surface_frame_token) IS NOT NULL
),
frame_gpu AS (
  SELECT
    f.id,
    f.dur,
    f.jank_type,
    SUM(g.freq_mhz * (MIN(g.ts + g.dur, f.ts + f.dur) - MAX(g.ts, f.ts)))
      / NULLIF(SUM(MIN(g.ts + g.dur, f.ts + f.dur) - MAX(g.ts, f.ts)), 0) as gpu_freq_mhz
  FROM frames f
  LEFT JOIN gpu g ON g.ts < f.ts + f.dur AND g.ts + g.dur > f.ts
  GROUP BY f.id
)
SELECT
  jank_type,
  COUNT(*) as frame_count,
  COUNT(gpu_freq_mhz) as frames_with_running_freq,
  ROUND(AVG(gpu_freq_mhz), 0) as avg_gpu_freq_mhz,
  ROUND(AVG(dur) / 1e6, 2) as avg_frame_dur_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_frame_dur_ms,
  ROUND(MIN(gpu_freq_mhz), 0) || ' - ' || ROUND(MAX(gpu_freq_mhz), 0) || ' MHz' as gpu_freq_range,
  (SELECT MIN(gpu_id) FROM gpu) as gpu_id
FROM frame_gpu
GROUP BY jank_type
ORDER BY frame_count DESC
LIMIT 10
