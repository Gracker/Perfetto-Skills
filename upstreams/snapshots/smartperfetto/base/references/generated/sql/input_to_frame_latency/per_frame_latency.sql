-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 40aedd3e7920ed09d8db24bb531a0799836e04ad1f129ba0b23358230a4af76d
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- The single read path for stdlib android_input_events. Skill contract:
-- event_action is the uppercase action without the Android prefix (MOVE, DOWN,
-- UP, CANCEL, ...). Newer trace processors report legacy atrace actions as
-- ACTION_MOVE/ACTION_DOWN/ACTION_UP; older ones reported MOVE/DOWN/UP. Every
-- other column passes through unchanged, NULL actions stay NULL. The column
-- list is the set every supported runtime has (v58.2 lacks frame_event_time);
-- keep it aligned with scrolling_analysis's input_data_fallback_view. NOT MATERIALIZED: consumers read it more than once
-- under their own filters, so SQLite should inline it rather than copy the table.
android_input_events_normalized AS NOT MATERIALIZED (
  SELECT
    dispatch_latency_dur, handling_latency_dur, ack_latency_dur,
    total_latency_dur, end_to_end_latency_dur,
    tid, thread_name, upid, pid, process_name,
    event_type,
    CASE WHEN event_action GLOB 'ACTION_*' THEN SUBSTR(event_action, 8)
      ELSE event_action END AS event_action,
    event_seq, event_channel, normalized_event_channel, input_event_id,
    read_time, dispatch_track_id, dispatch_ts, dispatch_dur,
    receive_ts, receive_dur, receive_track_id,
    frame_id, is_speculative_frame, event_time
  FROM android_input_events
)
,
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
vsync_cfg AS (
  SELECT COALESCE(
    CAST(PERCENTILE(interval_ns, 50) AS INTEGER),
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
  FROM android_input_events_normalized ie
  LEFT JOIN actual_frame_timeline_slice f
    ON ie.frame_id = f.surface_frame_token
    AND ie.upid = f.upid
  WHERE (('${package}' = '' OR ie.process_name = '${package}' OR ie.process_name GLOB '${package}:*') OR '${package}' = '')
    AND (ie.event_action = 'MOVE'
         OR ('${event_action_filter}' != '' AND '${event_action_filter}' IN (ie.event_action, 'ACTION_' || ie.event_action)))
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
