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
valid AS (
  SELECT end_to_end_latency_dur as latency_ns
  FROM android_input_events_normalized
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
    AND end_to_end_latency_dur IS NOT NULL
    AND end_to_end_latency_dur > 0
    AND end_to_end_latency_dur < 500000000
)
SELECT 'P50' as metric, ROUND(PERCENTILE(latency_ns, 50) / 1e6, 2) as value_ms FROM valid
UNION ALL
SELECT 'P90', ROUND(PERCENTILE(latency_ns, 90) / 1e6, 2) FROM valid
UNION ALL
SELECT 'P99', ROUND(PERCENTILE(latency_ns, 99) / 1e6, 2) FROM valid
UNION ALL
SELECT '均值', ROUND(AVG(latency_ns) / 1e6, 2) FROM valid
UNION ALL
SELECT '标准差', ROUND(SQRT(AVG(latency_ns * latency_ns) - AVG(latency_ns) * AVG(latency_ns)) / 1e6, 2) FROM valid
UNION ALL
SELECT '样本数', CAST(COUNT(*) AS REAL) FROM valid
UNION ALL
SELECT 'VSync周期(ms)', ROUND((SELECT period_ns FROM vsync_cfg) / 1e6, 2) FROM valid LIMIT 1
