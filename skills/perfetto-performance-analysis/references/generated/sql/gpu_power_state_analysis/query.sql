-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_power_state_analysis.skill.yaml
-- Source SHA-256: 0a4ae145d64ac7d9eddb15b2f73f8f209e360d4d06e87e8bb500751ee7162f6d
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH freq_samples AS (
  SELECT
    gpu_id,
    ts,
    gpu_freq,
    LAG(gpu_freq) OVER (PARTITION BY gpu_id ORDER BY ts) as prev_freq
  FROM android_gpu_frequency
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
transitions AS (
  SELECT
    gpu_id,
    gpu_freq,
    CASE
      WHEN prev_freq IS NULL THEN 'init'
      WHEN gpu_freq < prev_freq * (1 - ${transition_threshold_pct|15} / 100.0) THEN 'downshift'
      WHEN gpu_freq > prev_freq * (1 + ${transition_threshold_pct|15} / 100.0) THEN 'upshift'
      ELSE 'stable'
    END as transition_type
  FROM freq_samples
)
SELECT
  gpu_id,
  COUNT(*) as samples,
  ROUND(AVG(gpu_freq) / 1e6, 0) as avg_freq_mhz,
  ROUND(MIN(gpu_freq) / 1e6, 0) as min_freq_mhz,
  ROUND(MAX(gpu_freq) / 1e6, 0) as max_freq_mhz,
  SUM(CASE WHEN transition_type = 'downshift' THEN 1 ELSE 0 END) as downshift_count,
  SUM(CASE WHEN transition_type = 'upshift' THEN 1 ELSE 0 END) as upshift_count,
  ROUND(100.0 * SUM(CASE WHEN transition_type = 'downshift' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1) as downshift_ratio_pct
FROM transitions
GROUP BY gpu_id
