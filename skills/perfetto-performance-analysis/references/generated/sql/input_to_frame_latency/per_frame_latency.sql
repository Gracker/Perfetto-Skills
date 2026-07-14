-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 3f8a18a4750d12e34a5556236cf069b5e09eaf1c3c3cf2cc5af513f635809c46
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
vsync_cfg AS (
  SELECT COALESCE(
    CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER),
    16666667
  ) as period_ns
  FROM vsync_intervals
  WHERE interval_ns BETWEEN 5500000 AND 50000000
),
input_with_frame AS (
  SELECT
    ie.dispatch_ts as input_ts,
    ie.event_action,
    ie.process_name,
    ie.dispatch_latency_dur,
    ie.handling_latency_dur,
    ie.ack_latency_dur,
    ie.end_to_end_latency_dur,
    ie.is_speculative_frame,
    -- 用 frame_id 精确 JOIN 帧表获取帧内分解
    f.ts as frame_ts,
    f.dur as frame_dur,
    f.ts + f.dur as frame_present_ts
  FROM android_input_events ie
  LEFT JOIN actual_frame_timeline_slice f
    ON ie.frame_id = f.surface_frame_token
    AND ie.upid = f.upid
  WHERE (ie.process_name GLOB '${package}*' OR '${package}' = '')
    AND (ie.event_action = 'MOVE'
         OR ('${event_action_filter}' != '' AND ie.event_action = '${event_action_filter}'))
    AND (${start_ts} IS NULL OR ie.dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ie.dispatch_ts <= ${end_ts})
),
-- 预计算 e2e 延迟，避免重复 COALESCE（优先用 stdlib 的 end_to_end，fallback 到手动计算）
with_latency AS (
  SELECT
    *,
    COALESCE(end_to_end_latency_dur, frame_present_ts - input_ts) as e2e_ns
  FROM input_with_frame
  WHERE (end_to_end_latency_dur IS NOT NULL OR frame_present_ts IS NOT NULL)
)
SELECT
  printf('%d', input_ts) as input_ts,
  process_name,
  event_action,
  ROUND(e2e_ns / 1e6, 2) as input_to_display_ms,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_latency_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_ms,
  ROUND(frame_dur / 1e6, 2) as frame_dur_ms,
  ROUND((frame_present_ts - frame_ts - COALESCE(frame_dur, 0)) / 1e6, 2) as frame_to_present_ms,
  is_speculative_frame as is_speculative,
  CASE
    WHEN e2e_ns / 1e6 < 2 * (SELECT period_ns FROM vsync_cfg) / 1e6 THEN '优秀'
    WHEN e2e_ns / 1e6 < 3 * (SELECT period_ns FROM vsync_cfg) / 1e6 THEN '良好'
    WHEN e2e_ns / 1e6 < 4 * (SELECT period_ns FROM vsync_cfg) / 1e6 THEN '需优化'
    ELSE '严重'
  END as rating
FROM with_latency
WHERE e2e_ns > 0 AND e2e_ns < 500000000
ORDER BY input_ts
