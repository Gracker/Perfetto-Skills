-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: d239238edb11e6aaf345c18ec79d0113282a99855c089f8653a6ef42c93ddef6
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
SELECT
  CASE
    WHEN total_latency_dur / 1e6 < 16 THEN '<16ms (极快)'
    WHEN total_latency_dur / 1e6 < 50 THEN '16-50ms (快)'
    WHEN total_latency_dur / 1e6 < 100 THEN '50-100ms (正常)'
    WHEN total_latency_dur / 1e6 < 200 THEN '100-200ms (慢)'
    ELSE '>200ms (很慢)'
  END as latency_bucket,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / (
    SELECT COUNT(*) FROM android_input_events_normalized
    WHERE process_name = '${target_process.data[0].process_name}'
      AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
      AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
  ), 1) as percent
FROM android_input_events_normalized
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY latency_bucket
ORDER BY
  CASE latency_bucket
    WHEN '<16ms (极快)' THEN 1
    WHEN '16-50ms (快)' THEN 2
    WHEN '50-100ms (正常)' THEN 3
    WHEN '100-200ms (慢)' THEN 4
    ELSE 5
  END
