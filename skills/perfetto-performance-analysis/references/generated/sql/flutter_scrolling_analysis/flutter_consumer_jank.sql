-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
-- Source SHA-256: 1948ff2572667b9c7ccba73cb1bc9334c36b3ae6f6ae78371b7c64e154421c72
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
flutter_app_frames AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as dur,
    COALESCE(a.jank_type, 'Unknown') as jank_type,
    a.layer_name,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts, COALESCE(a.display_frame_token, a.surface_frame_token)) as prev_present_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (
    '${package}' = '' OR p.name LIKE '%${package}%'
  )
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
jank_analysis AS (
  SELECT
    jank_type,
    dur,
    present_ts - prev_present_ts as interval_ns,
    CASE
      WHEN prev_present_ts IS NULL THEN 1
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns * 6 FROM vsync_config) THEN 1
      ELSE 0
    END as is_session_break,
    CASE
      WHEN prev_present_ts IS NULL THEN 0
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns * 6 FROM vsync_config) THEN 0
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_config) * 1.5 THEN 1
      ELSE 0
    END as is_consumer_jank
  FROM flutter_app_frames
  WHERE prev_present_ts IS NOT NULL
)
SELECT
  jank_type,
  COUNT(*) as count,
  -- 实际用户感知掉帧数（呈现间隔 > 1.5 * VSync）
  SUM(is_consumer_jank) as real_jank_count,
  -- 隐藏掉帧（jank_type=None 但消费端实际掉帧）
  SUM(CASE WHEN jank_type = 'None' AND is_consumer_jank = 1 THEN 1 ELSE 0 END) as hidden_jank_count,
  -- 假阳性（jank_type 报告掉帧，但消费端未跳帧）
  SUM(CASE WHEN jank_type != 'None' AND is_consumer_jank = 0 THEN 1 ELSE 0 END) as false_positive,
  CAST(ROUND(AVG(CASE WHEN dur > 0 THEN dur ELSE NULL END)) AS INTEGER) as avg_dur,
  CASE
    WHEN jank_type GLOB '*App*' OR jank_type = 'Self Jank' THEN '标签:App'
    WHEN jank_type GLOB '*SurfaceFlinger*' THEN '标签:SurfaceFlinger'
    WHEN jank_type GLOB '*Buffer*' THEN '标签:Buffer Stuffing(需验证)'
    WHEN jank_type = 'None' THEN '标签:None(可能漏检)'
    ELSE '标签:Other'
  END as responsibility
FROM jank_analysis
WHERE is_session_break = 0
GROUP BY jank_type
ORDER BY real_jank_count DESC, count DESC
LIMIT 10
