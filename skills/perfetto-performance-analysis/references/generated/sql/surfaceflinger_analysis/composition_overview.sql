-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH
sf_compositions AS (
  SELECT
    s.ts,
    s.dur,
    s.name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
    AND (s.name GLOB '*onMessageInvalidate*'
         OR s.name GLOB '*onMessageRefresh*'
         OR s.name GLOB '*composite*'
         OR s.name GLOB '*Composite*')
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
)
SELECT
  COUNT(*) as total_compositions,
  CAST(ROUND(AVG(dur)) AS INTEGER) as avg_composition_dur,
  MAX(dur) as max_composition_dur,
  CAST(ROUND(PERCENTILE(dur, 0.95)) AS INTEGER) as p95_composition_dur,
  ROUND(AVG(dur) / 1e6, 2) as avg_composition_ms,
  SUM(CASE WHEN dur > ${vsync_env.data[0].vsync_period_ns} * ${slow_composition_multiplier|1.5} THEN 1 ELSE 0 END) as slow_composition_count,
  CASE
    WHEN AVG(dur) / 1e6 > ${composition_rating_poor_ms|12} THEN '较差'
    WHEN AVG(dur) / 1e6 > ${composition_rating_fair_ms|8} THEN '一般'
    WHEN AVG(dur) / 1e6 > ${composition_rating_good_ms|4} THEN '良好'
    ELSE '优秀'
  END as rating
FROM sf_compositions
