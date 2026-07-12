-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_frequency_analysis.skill.yaml
-- Source SHA-256: d8233f4d110ef07ec6469fa923b1ac018e0e6e0993faa2e079bf8d58bbc6b408
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH gpu_freq AS (
  SELECT
    c.ts,
    CAST(c.value AS INTEGER) as freq_khz,
    ct.name as track_name
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name GLOB '*gpu*freq*' OR ct.name GLOB '*mali*freq*'
         OR ct.name GLOB '*adreno*freq*' OR ct.name GLOB '*img*freq*')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
stats AS (
  SELECT
    COUNT(*) as sample_count,
    MIN(freq_khz) as min_freq,
    MAX(freq_khz) as max_freq,
    ROUND(AVG(freq_khz), 0) as avg_freq,
    track_name
  FROM gpu_freq
  GROUP BY track_name
)
SELECT 'GPU 频率源' as metric, COALESCE(track_name, '未检测到 GPU 频率 counter') as value,
  CASE WHEN track_name IS NULL THEN '⚠️ 无 GPU 频率数据（trace 中无 gpu freq counter）' ELSE '' END as assessment
FROM stats
UNION ALL
SELECT 'GPU 频率源' as metric, '未检测到 GPU 频率 counter' as value, '⚠️ 无 GPU 频率数据' as assessment
WHERE NOT EXISTS (SELECT 1 FROM stats)
UNION ALL
SELECT 'GPU 均频' as metric,
  ROUND(avg_freq / 1000.0, 0) || ' MHz' as value,
  CASE WHEN avg_freq < max_freq * 0.6 THEN '⚠️ GPU 频率偏低，可能存在 thermal 限频'
       ELSE '✓ 正常' END as assessment
FROM stats
UNION ALL
SELECT 'GPU 峰值频率' as metric, ROUND(max_freq / 1000.0, 0) || ' MHz' as value, '' as assessment FROM stats
UNION ALL
SELECT 'GPU 最低频率' as metric, ROUND(min_freq / 1000.0, 0) || ' MHz' as value,
  CASE WHEN min_freq < max_freq * 0.3 THEN '⚠️ GPU 曾深度降频'
       ELSE '✓ 频率波动正常' END as assessment
FROM stats
UNION ALL
SELECT 'GPU 频率变化次数' as metric, CAST(sample_count AS TEXT) as value, '' as assessment FROM stats
