-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: b4e342987eae11ebb02d0693221a0e10ba48572187f89156a889763249cd5cf8
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
-- Frame association: the stdlib matches an event to the Choreographer#doFrame
-- its delivery overlaps (exact) or else to the next doFrame on the receiving
-- thread with no time bound (is_speculative_frame = 1), and derives
-- end_to_end_latency_dur from that frame. A speculative frame is a candidate,
-- not proof the event was consumed there, so frame linkage, presentation
-- latency and per-frame attribution read exact_frame_id /
-- exact_end_to_end_latency_dur. frame_association labels raw values for
-- display: none, exact, speculative, or unknown (a frame with no flag, which
-- is not treated as exact).
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
    frame_id, is_speculative_frame, event_time,
    CASE WHEN frame_id IS NOT NULL AND is_speculative_frame = 0
      THEN frame_id END AS exact_frame_id,
    CASE WHEN frame_id IS NOT NULL AND is_speculative_frame = 0
      THEN end_to_end_latency_dur END AS exact_end_to_end_latency_dur,
    CASE
      WHEN frame_id IS NULL THEN 'none'
      WHEN is_speculative_frame = 0 THEN 'exact'
      WHEN is_speculative_frame = 1 THEN 'speculative'
      ELSE 'unknown'
    END AS frame_association
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
