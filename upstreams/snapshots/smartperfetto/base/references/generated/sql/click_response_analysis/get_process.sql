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
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Which receiver of a physical input event is its application delivery.
-- android_input_events has one row per receiving channel of the same physical
-- event (input_event_id): the app window plus gesture monitors, the pointer
-- dispatcher, wallpaper and navigation bar channels. The stdlib sets
-- event_action only from app-side delivery evidence on a window the receiving
-- process owns, so monitor channels never carry it; an app delivery can still
-- lack it (no `view` atrace, no frame after the event).
--   action       - event_action is known: an observed application delivery.
--   monitor_copy - NULL action, and another row of the same input_event_id
--                  carries one: a monitor observation, not the app's.
--   unresolved   - NULL action on every receiver of the event (trace-edge
--                  events, FOCUS, runtimes that resolve no action).
-- unresolved_event_key identifies an unresolved event once per input_event_id,
-- so counting it DISTINCT gives extra channels of one event no extra weight.
-- Classified over the whole relation, never inside a caller's time window, so a
-- window edge cannot separate a copy from its action-bearing sibling.
-- scene_input_facts.sql applies the same "the action-bearing receiver is
-- primary" rule per stream for scene reconstruction.
-- Requires fragments/android_input_events_normalized.sql listed before it.
android_input_action_event_ids AS (
  SELECT DISTINCT input_event_id
  FROM android_input_events_normalized
  WHERE event_action IS NOT NULL AND input_event_id IS NOT NULL
),
android_input_event_deliveries AS NOT MATERIALIZED (
  SELECT e.*,
    CASE WHEN e.event_action IS NOT NULL THEN 'action'
      WHEN a.input_event_id IS NOT NULL THEN 'monitor_copy'
      ELSE 'unresolved' END AS delivery_role,
    CASE WHEN e.event_action IS NULL AND a.input_event_id IS NULL
      THEN COALESCE(e.input_event_id, 'dispatch:' || e.dispatch_ts) END AS unresolved_event_key
  FROM android_input_events_normalized AS e
  LEFT JOIN android_input_action_event_ids AS a ON a.input_event_id = e.input_event_id
)
SELECT
  process_name,
  COUNT(*) as event_count,
  SUM(delivery_role = 'action') as app_delivery_events,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_total_ms
FROM android_input_event_deliveries
WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY process_name
ORDER BY app_delivery_events DESC,
  COUNT(DISTINCT unresolved_event_key) DESC,
  MAX(total_latency_dur) DESC, process_name
LIMIT 1
