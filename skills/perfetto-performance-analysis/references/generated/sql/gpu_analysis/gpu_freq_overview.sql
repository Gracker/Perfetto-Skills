-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: c99bd1159e7f337b0d5dd490100f66e9134271d55a7bbf0362ebf64d3a1d9602
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
gpu_freq_filtered AS (
  SELECT
    gpu_id,
    gpu_freq,
    dur,
    ts
  FROM android_gpu_frequency
  WHERE dur > 0
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
max_freq_per_gpu AS (
  SELECT gpu_id, MAX(gpu_freq) as max_gpu_freq
  FROM gpu_freq_filtered
  GROUP BY gpu_id
),
gpu_stats AS (
  SELECT
    g.gpu_id,
    -- 加权平均频率 (按持续时间加权)
    ROUND(SUM(g.gpu_freq * 1.0 * g.dur) / NULLIF(SUM(g.dur), 0) / 1e6, 0) as weighted_avg_freq_mhz,
    ROUND(MAX(g.gpu_freq) / 1e6, 0) as max_freq_mhz,
    ROUND(MIN(g.gpu_freq) / 1e6, 0) as min_freq_mhz,
    -- 最高频占比
    ROUND(100.0 * SUM(CASE WHEN g.gpu_freq = mf.max_gpu_freq THEN g.dur ELSE 0 END) / NULLIF(SUM(g.dur), 0), 1) as max_freq_time_pct,
    COUNT(DISTINCT g.gpu_freq) as freq_levels,
    -- 变频次数 (频率不同于上一条记录的次数)
    (SELECT COUNT(*) FROM android_gpu_frequency f2
     WHERE f2.gpu_id = g.gpu_id
       AND f2.prev_gpu_freq IS NOT NULL
       AND f2.gpu_freq != f2.prev_gpu_freq
       AND (${start_ts} IS NULL OR f2.ts >= ${start_ts})
       AND (${end_ts} IS NULL OR f2.ts < ${end_ts})
    ) as freq_change_count,
    ROUND(SUM(g.dur) / 1e9, 2) as total_time_sec
  FROM gpu_freq_filtered g
  JOIN max_freq_per_gpu mf ON g.gpu_id = mf.gpu_id
  GROUP BY g.gpu_id
)
SELECT
  gpu_id,
  weighted_avg_freq_mhz,
  max_freq_mhz,
  min_freq_mhz,
  max_freq_time_pct,
  freq_levels,
  freq_change_count,
  total_time_sec,
  CASE
    WHEN max_freq_time_pct > ${high_freq_threshold_pct|70} THEN '高负载'
    WHEN max_freq_time_pct > ${mid_freq_threshold_pct|40} THEN '中负载'
    WHEN max_freq_time_pct > ${low_freq_threshold_pct|10} THEN '低负载'
    ELSE '空闲'
  END as rating
FROM gpu_stats
ORDER BY gpu_id
