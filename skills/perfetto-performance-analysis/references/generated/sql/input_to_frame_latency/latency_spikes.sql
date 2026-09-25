-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 40aedd3e7920ed09d8db24bb531a0799836e04ad1f129ba0b23358230a4af76d
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
latencies AS (
  SELECT
    dispatch_ts as input_ts,
    end_to_end_latency_dur as latency_ns,
    is_speculative_frame
  FROM android_input_events_normalized
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
    AND end_to_end_latency_dur IS NOT NULL
    AND end_to_end_latency_dur > 0
    AND end_to_end_latency_dur < 500000000
),
with_prev AS (
  SELECT
    input_ts,
    latency_ns,
    is_speculative_frame,
    LAG(latency_ns) OVER (ORDER BY input_ts) as prev_latency_ns
  FROM latencies
)
SELECT
  printf('%d', input_ts) as input_ts,
  ROUND(latency_ns / 1e6, 2) as latency_ms,
  ROUND(prev_latency_ns / 1e6, 2) as prev_latency_ms,
  ROUND(CAST(latency_ns AS REAL) / MAX(prev_latency_ns, 1), 1) as spike_ratio,
  is_speculative_frame as is_speculative
FROM with_prev
WHERE prev_latency_ns IS NOT NULL
  AND latency_ns > prev_latency_ns * 2
  AND latency_ns > 30000000
ORDER BY spike_ratio DESC
LIMIT 20
