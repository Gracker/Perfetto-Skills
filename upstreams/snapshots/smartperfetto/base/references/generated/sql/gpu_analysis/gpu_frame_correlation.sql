-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: ccca4067c8ee136de6c5a431984bc78be6e76efd3e44164776f7513e754a9c90

-- Each frame against each GPU: the running frequency weighted by time
-- inside the frame, leaving out time that GPU was off. Which GPU renders
-- a frame is not in the trace, so every GPU gets its own rows rather than
-- one being picked. A GPU often powers up after a frame starts, so a
-- frame whose interval holds no running time on a GPU is counted, not
-- dropped, and has no frequency there. The overlap is an interval
-- intersection: a per-frame range scan costs frames x GPUs x intervals.
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
  SELECT counter_id AS id, ts, dur, freq_mhz, gpu_id
  FROM gpu_frequency_intervals
  WHERE freq_mhz > 0 AND dur > 0
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
frame_gpu_keys AS MATERIALIZED (
  SELECT ROW_NUMBER() OVER () AS id, f.id AS frame_id, f.ts, f.dur, f.jank_type, k.gpu_id
  FROM frames f
  CROSS JOIN (SELECT DISTINCT gpu_id FROM gpu_frequency_samples) k
),
running AS MATERIALIZED (
  SELECT ii.id_0 AS key_id, SUM(g.freq_mhz * ii.dur) AS weighted, SUM(ii.dur) AS running_dur
  FROM _interval_intersect!((frame_gpu_keys, gpu), (gpu_id)) AS ii
  JOIN gpu AS g ON g.id = ii.id_1
  GROUP BY ii.id_0
),
per_type AS (
  SELECT
    k.gpu_id,
    k.jank_type,
    COUNT(*) as frame_count,
    COUNT(r.key_id) as frames_with_running_freq,
    ROUND(AVG(r.weighted / r.running_dur), 0) as avg_gpu_freq_mhz,
    ROUND(AVG(k.dur) / 1e6, 2) as avg_frame_dur_ms,
    ROUND(MAX(k.dur) / 1e6, 2) as max_frame_dur_ms,
    ROUND(MIN(r.weighted / r.running_dur), 0) || ' - ' || ROUND(MAX(r.weighted / r.running_dur), 0) || ' MHz' as gpu_freq_range
  FROM frame_gpu_keys k
  LEFT JOIN running r ON r.key_id = k.id
  GROUP BY k.gpu_id, k.jank_type
)
SELECT gpu_id, jank_type, frame_count, frames_with_running_freq, avg_gpu_freq_mhz,
  avg_frame_dur_ms, max_frame_dur_ms, gpu_freq_range
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY gpu_id ORDER BY frame_count DESC, jank_type) AS type_rank
  FROM per_type
)
WHERE type_rank <= 10
ORDER BY gpu_id, frame_count DESC, jank_type
