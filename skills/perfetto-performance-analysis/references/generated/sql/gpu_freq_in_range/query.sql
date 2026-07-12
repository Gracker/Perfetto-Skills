-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_freq_in_range.skill.yaml
-- Source SHA-256: 6b78313b5cf0ad8f7be13fe1f517af3abdf7bce59f14197d95242dbca036c4ba
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH gpu_raw AS (
  SELECT gpu_id, gpu_freq, dur
  FROM android_gpu_frequency
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts}) AND (${end_ts} IS NULL OR ts < ${end_ts})
),
gpu_max AS (
  SELECT gpu_id, MAX(gpu_freq) as max_freq
  FROM gpu_raw
  GROUP BY gpu_id
),
gpu_samples AS (
  SELECT
    r.gpu_id,
    r.gpu_freq,
    r.dur,
    CASE WHEN r.gpu_freq < m.max_freq * ${low_freq_threshold_pct|40} / 100.0
         THEN r.dur ELSE 0 END as low_freq_dur
  FROM gpu_raw r
  JOIN gpu_max m ON r.gpu_id = m.gpu_id
)
SELECT
  gpu_id,
  ROUND(SUM(gpu_freq * dur) / NULLIF(SUM(dur), 0) / 1e6, 0) as avg_freq_mhz,
  ROUND(MAX(gpu_freq) / 1e6, 0) as max_freq_mhz,
  ROUND(MIN(gpu_freq) / 1e6, 0) as min_freq_mhz,
  COUNT(DISTINCT gpu_freq) as freq_changes,
  ROUND(100.0 * SUM(low_freq_dur) / NULLIF(SUM(dur), 0), 1) as low_freq_pct
FROM gpu_samples
GROUP BY gpu_id
