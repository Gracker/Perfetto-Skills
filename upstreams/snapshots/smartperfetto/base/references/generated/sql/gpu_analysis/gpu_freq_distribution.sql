-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 36f5184c4bd50b7001d0a1d14acaee52592734ad5771dec48bb5e811a7c66b96
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
max_freq_per_gpu AS (
  SELECT gpu_id, MAX(gpu_freq) as max_gpu_freq
  FROM android_gpu_frequency
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  GROUP BY gpu_id
)
SELECT
  g.gpu_id,
  ROUND(g.gpu_freq / 1e6, 0) as gpu_freq_mhz,
  ROUND(SUM(g.dur) / 1e9, 3) as total_time_sec,
  ROUND(100.0 * SUM(g.dur) / NULLIF(
    (SELECT SUM(dur) FROM android_gpu_frequency
     WHERE gpu_id = g.gpu_id AND dur > 0
       AND (${start_ts} IS NULL OR ts >= ${start_ts})
       AND (${end_ts} IS NULL OR ts < ${end_ts})),
    0), 2) as time_pct,
  CASE WHEN g.gpu_freq = mf.max_gpu_freq THEN '是' ELSE '' END as is_max_freq
FROM android_gpu_frequency g
JOIN max_freq_per_gpu mf ON g.gpu_id = mf.gpu_id
WHERE g.dur > 0
  AND (${start_ts} IS NULL OR g.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR g.ts < ${end_ts})
GROUP BY g.gpu_id, g.gpu_freq
ORDER BY g.gpu_id, g.gpu_freq DESC
