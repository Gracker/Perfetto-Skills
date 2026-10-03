-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 80fe51882560c325dcd072ed62a0c07db6b43a2fdf215b072b366077ec1fbf51

-- MHz. The gpufreq track is normalized by
-- fragments/gpu_frequency_intervals.sql; other GPU frequency counters
-- are converted by the unit they declare
-- (fragments/gpu_descriptor_frequency_tracks.sql), and one without a
-- known unit is named, not guessed at.
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

-- No input CTE. GPU counter tracks other than the trace_processor gpufreq
-- (fragments/gpu_frequency_intervals.sql) whose name says frequency or clock:
-- GpuCounterDescriptor counters, which declare their own unit. to_mhz
-- converts a declared MHz, kHz or Hz; it is NULL for any other or no unit,
-- and such a track is named rather than read by guessing its unit.
gpu_descriptor_frequency_tracks AS (
  SELECT
    t.id,
    t.name,
    t.unit,
    CASE t.unit WHEN 'MHz' THEN 1.0 WHEN 'kHz' THEN 1e-3 WHEN 'Hz' THEN 1e-6 END AS to_mhz
  FROM gpu_counter_track t
  WHERE t.name != 'gpufreq'
    AND (LOWER(t.name) GLOB '*freq*' OR LOWER(t.name) GLOB '*clock*')
)
,
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(c.ts)) as start_ts,
    COALESCE(${end_ts}, MAX(c.ts)) as end_ts
  FROM counter c
),
gpu_freq AS (
  SELECT freq_mhz, 'gpufreq' as counter_name
  FROM gpu_frequency_intervals
  WHERE ts >= (SELECT start_ts FROM time_bounds)
    AND ts <= (SELECT end_ts FROM time_bounds)
  UNION ALL
  SELECT c.value * t.to_mhz as freq_mhz, t.name as counter_name
  FROM counter c
  JOIN gpu_descriptor_frequency_tracks t ON c.track_id = t.id
  WHERE t.to_mhz IS NOT NULL
    AND c.ts >= (SELECT start_ts FROM time_bounds)
    AND c.ts <= (SELECT end_ts FROM time_bounds)
)
SELECT
  ROUND(AVG(freq_mhz), 0) as avg_freq_mhz,
  ROUND(MAX(freq_mhz), 0) as max_freq_mhz,
  ROUND(MIN(freq_mhz), 0) as min_freq_mhz,
  ROUND(PERCENTILE(freq_mhz, 50), 0) as median_freq_mhz,
  COUNT(*) as sample_count,
  GROUP_CONCAT(DISTINCT counter_name) as freq_counters,
  (SELECT GROUP_CONCAT(name) FROM gpu_descriptor_frequency_tracks WHERE to_mhz IS NULL) as undeclared_unit_counters
FROM gpu_freq
WHERE freq_mhz > 0
