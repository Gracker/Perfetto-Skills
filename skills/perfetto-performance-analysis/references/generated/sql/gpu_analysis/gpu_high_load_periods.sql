-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: c99bd1159e7f337b0d5dd490100f66e9134271d55a7bbf0362ebf64d3a1d9602
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH
max_freq AS (
  SELECT gpu_id, MAX(gpu_freq) as max_gpu_freq
  FROM android_gpu_frequency
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  GROUP BY gpu_id
),
high_freq_periods AS (
  SELECT
    g.gpu_id,
    g.ts,
    g.dur,
    g.gpu_freq,
    -- 按秒聚合
    CAST(g.ts / 1000000000 AS INTEGER) as time_bucket
  FROM android_gpu_frequency g
  JOIN max_freq mf ON g.gpu_id = mf.gpu_id
  WHERE g.gpu_freq >= mf.max_gpu_freq * 0.9
    AND g.dur > 0
    AND (${start_ts} IS NULL OR g.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR g.ts < ${end_ts})
)
SELECT
  gpu_id,
  printf('%d', MIN(ts)) as start_ts,
  ROUND(SUM(dur) / 1e6, 1) as high_freq_dur_ms,
  COUNT(*) as segment_count,
  printf('%d', MAX(ts + dur) - MIN(ts)) as duration_ns
FROM high_freq_periods
GROUP BY gpu_id, time_bucket
HAVING SUM(dur) > ${high_load_min_dur_ns|500000000}  -- > 500ms of high freq per second bucket
ORDER BY MIN(ts)
LIMIT 20
