-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 579fe2d70ef30c53d7a5e32a06732ef2872ce8b45c31aea88cb079bf2a45c9e0

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
-- MHz. gpufreq is normalized by fragments/gpu_frequency_intervals.sql,
-- leaving out time the GPU was off; another GPU frequency counter is
-- converted only by the unit it declares.
SELECT
  'gpufreq' AS counter_name,
  gpu_id,
  ROUND(SUM(freq_mhz * dur) / NULLIF(SUM(dur), 0), 0) AS avg_freq_mhz,
  ROUND(MAX(freq_mhz), 0) AS max_freq_mhz,
  ROUND(MIN(freq_mhz), 0) AS min_freq_mhz
FROM gpu_frequency_intervals
WHERE freq_mhz > 0 AND dur > 0
GROUP BY gpu_id
UNION ALL
SELECT
  t.name AS counter_name,
  NULL AS gpu_id,
  ROUND(AVG(c.value * t.to_mhz), 0) AS avg_freq_mhz,
  ROUND(MAX(c.value * t.to_mhz), 0) AS max_freq_mhz,
  ROUND(MIN(c.value * t.to_mhz), 0) AS min_freq_mhz
FROM counter c
JOIN gpu_descriptor_frequency_tracks t ON c.track_id = t.id
WHERE t.to_mhz IS NOT NULL
GROUP BY t.name
UNION ALL
-- A frequency counter without a known unit is named, not read.
SELECT t.name || '（单位未声明）', NULL, NULL, NULL, NULL
FROM gpu_descriptor_frequency_tracks t
WHERE t.to_mhz IS NULL
