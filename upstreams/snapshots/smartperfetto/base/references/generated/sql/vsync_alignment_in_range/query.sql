-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_alignment_in_range.skill.yaml
-- Source SHA-256: a2b69b59ec5a9385f3c650a2504f801f4dcbba67d2016b4461eb313ae5a2083c
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH vsync_ticks AS (
  SELECT c.ts, c.value,
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE (t.name LIKE '%VSYNC-sf%' OR t.name LIKE '%VSYNC-app%' OR t.name = 'VSYNC')
    AND c.ts >= ${start_ts} - 100000000  -- 往前看 100ms
    AND c.ts < ${end_ts} + 100000000
),
vsync_period AS (
  SELECT AVG(interval_ns) as period_ns
  FROM vsync_ticks
  WHERE interval_ns > 5000000 AND interval_ns < 50000000  -- 20Hz-200Hz
),
frame_timing AS (
  SELECT
    ${start_ts} as frame_start,
    ${end_ts} as frame_end,
    ${end_ts} - ${start_ts} as frame_dur,
    (SELECT MIN(ts) FROM vsync_ticks WHERE ts >= ${start_ts}) as next_vsync_after_start,
    (SELECT MAX(ts) FROM vsync_ticks WHERE ts < ${start_ts}) as prev_vsync_before_start,
    (SELECT MIN(ts) FROM vsync_ticks WHERE ts >= ${end_ts}) as next_vsync_after_end,
    (SELECT period_ns FROM vsync_period) as vsync_period
)
SELECT 'VSync 周期' as metric,
  CASE
    WHEN vsync_period IS NULL THEN '无数据'
    ELSE ROUND(vsync_period / 1e6, 2) || 'ms (' || ROUND(1e9 / vsync_period, 0) || 'Hz)'
  END as value
FROM frame_timing
UNION ALL
SELECT '帧耗时' as metric,
  ROUND(frame_dur / 1e6, 2) || 'ms' as value
FROM frame_timing
UNION ALL
SELECT '相对 VSync 周期' as metric,
  CASE
    WHEN vsync_period IS NULL OR vsync_period = 0 THEN '无数据'
    ELSE ROUND(100.0 * frame_dur / vsync_period, 1) || '%'
  END as value
FROM frame_timing
UNION ALL
SELECT '帧起点偏移' as metric,
  CASE
    WHEN prev_vsync_before_start IS NULL THEN '无数据'
    ELSE ROUND((frame_start - prev_vsync_before_start) / 1e6, 2) || 'ms (距上次VSync)'
  END as value
FROM frame_timing
UNION ALL
SELECT '截止时间' as metric,
  CASE
    WHEN next_vsync_after_start IS NULL THEN '无数据'
    WHEN frame_end > next_vsync_after_start THEN
      '超时 ' || ROUND((frame_end - next_vsync_after_start) / 1e6, 2) || 'ms'
    ELSE
      '提前 ' || ROUND((next_vsync_after_start - frame_end) / 1e6, 2) || 'ms'
  END as value
FROM frame_timing
