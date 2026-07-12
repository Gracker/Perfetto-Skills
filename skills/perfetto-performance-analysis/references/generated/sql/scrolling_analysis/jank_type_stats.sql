-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
vsync_intervals AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
app_frames AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as dur,
    COALESCE(a.jank_type, 'Unknown') as jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.layer_name,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) as prev_present_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
-- 掉帧检测：双信号混合策略
jank_analysis AS (
  SELECT
    jank_type,
    dur,
    -- is_consumer_jank: 双信号混合检测
    CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND jank_type != 'Buffer Stuffing' THEN 1
      WHEN jank_type = 'Buffer Stuffing'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config) * 6 THEN 1
      ELSE 0
    END as is_consumer_jank
  FROM app_frames
)
SELECT
  jank_type,
  COUNT(*) as count,
  -- 实际用户感知掉帧数（present_type 为 Late/Dropped）
  SUM(is_consumer_jank) as real_jank_count,
  -- 假阳性数（jank_type 报告掉帧，但 present_type 未标记为 Late/Dropped）
  SUM(CASE WHEN jank_type != 'None' AND is_consumer_jank = 0 THEN 1 ELSE 0 END) as false_positive,
  CAST(SUM(CASE WHEN dur > 0 THEN dur ELSE 0 END) AS REAL) as total_dur,
  CAST(ROUND(AVG(CASE WHEN dur > 0 THEN dur ELSE NULL END)) AS INTEGER) as avg_dur,
  CASE
    WHEN jank_type GLOB '*App*' OR jank_type = 'Self Jank' THEN '标签:App'
    WHEN jank_type GLOB '*SurfaceFlinger*' THEN '标签:SurfaceFlinger'
    WHEN jank_type = 'Buffer Stuffing' THEN '标签:Buffer Stuffing(需验证)'
    WHEN jank_type = 'None' THEN '标签:None(可能漏检)'
    ELSE '标签:Other'
  END as responsibility
FROM jank_analysis
GROUP BY jank_type
ORDER BY real_jank_count DESC, count DESC
LIMIT 10
