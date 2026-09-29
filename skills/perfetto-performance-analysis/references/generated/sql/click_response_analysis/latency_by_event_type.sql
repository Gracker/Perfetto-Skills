-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 6d9b8d7751e14a4a990e7b9d80569a1195dfffe8f7c0f93e3a5c714f12b62a68

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
-- physical_event_key names the physical event a row delivers: every receiving
-- channel of one event shares it, so COUNT(DISTINCT physical_event_key) counts
-- events however many channels (app window, gesture monitors, dispatcher,
-- navigation bar) received each. Without an input_event_id the dispatch
-- timestamp stands in, which identifies only that one delivery. (The
-- physical_event_key of scene_input_facts.sql is a different, scene-local key
-- that also spans native motion/key events.)
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
    END AS frame_association,
    COALESCE(input_event_id, 'dispatch:' || dispatch_ts) AS physical_event_key
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
-- unresolved_event_key is the physical_event_key of an unresolved row, so
-- counting it DISTINCT gives extra channels of one event no extra weight.
-- window_owner is the stdlib's owner of the receiving channel,
-- str_split(str_split(event_channel, ' ', 1), '/', 0), spelled portably: the
-- package of a '<hash> <package>/<component>' window. Monitor, dispatcher,
-- navigation-bar and wallpaper channels never yield their receiver's name; nor
-- do app windows titled without '/' (PopupWindow:..), which keep plain counts.
-- unresolved_window_event_key keeps an unresolved event only on a window its
-- receiver owns: the exact name, or the name before ':' for multi-process apps,
-- whose delivery the stdlib cannot resolve (substr, not GLOB: the owner is
-- channel text). Rankers read it right after the action count, because a
-- monitor sees touches aimed at every window and can out-count the app.
-- monitor_observation marks rows that observe an event rather than deliver it
-- to the application: every monitor_copy, and an unresolved row on a receiving
-- channel (upid + event_channel) that never carries an action but does carry
-- monitor copies. A process can own both its app window and a gesture monitor
-- (a launcher's "[Gesture Monitor] swipe-up"); when an event's action is
-- unresolved on every receiver, the channel's history is what still separates
-- the monitor's row from the window's. Channels are judged from data, never
-- from their names. fragments/android_input_scoped_deliveries.sql turns this
-- into the rows a caller analyzes inside its window.
-- Classified over the whole relation, never inside a caller's time window, so a
-- window edge cannot separate a copy from its action-bearing sibling.
-- scene_input_facts.sql applies the same "the action-bearing receiver is
-- primary" rule per stream for scene reconstruction, without window ownership.
-- Requires fragments/android_input_events_normalized.sql listed before it.
android_input_action_event_ids AS (
  SELECT DISTINCT input_event_id
  FROM android_input_events_normalized
  WHERE event_action IS NOT NULL AND input_event_id IS NOT NULL
),
android_input_monitor_channels AS (
  SELECT e.upid, e.event_channel
  FROM android_input_events_normalized AS e
  LEFT JOIN android_input_action_event_ids AS a ON a.input_event_id = e.input_event_id
  WHERE e.event_channel IS NOT NULL
  GROUP BY e.upid, e.event_channel
  HAVING COUNT(e.event_action) = 0 AND COUNT(a.input_event_id) > 0
),
android_input_event_deliveries AS NOT MATERIALIZED (
  SELECT d.*,
    CASE WHEN d.window_owner != ''
      AND substr(d.process_name || ':', 1, length(d.window_owner) + 1) = d.window_owner || ':'
      THEN d.unresolved_event_key END AS unresolved_window_event_key
  FROM (
    SELECT e.*,
      CASE WHEN e.event_action IS NOT NULL THEN 'action'
        WHEN a.input_event_id IS NOT NULL THEN 'monitor_copy'
        ELSE 'unresolved' END AS delivery_role,
      CASE WHEN e.event_action IS NULL AND a.input_event_id IS NULL
        THEN e.physical_event_key END AS unresolved_event_key,
      (e.event_action IS NULL
        AND (a.input_event_id IS NOT NULL OR m.upid IS NOT NULL)) AS monitor_observation,
      -- Second word of the channel, cut at its first '/'.
      CASE WHEN instr(e.event_channel, ' ') > 0 THEN substr(
        replace(substr(e.event_channel, instr(e.event_channel, ' ') + 1), '/', ' '), 1,
        instr(replace(substr(e.event_channel, instr(e.event_channel, ' ') + 1), '/', ' ') || ' ', ' ') - 1)
      END AS window_owner
    FROM android_input_events_normalized AS e
    LEFT JOIN android_input_action_event_ids AS a ON a.input_event_id = e.input_event_id
    LEFT JOIN android_input_monitor_channels AS m
      ON m.upid = e.upid AND m.event_channel = e.event_channel
  ) AS d
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- The input deliveries a caller analyzes inside its time window. A process
-- keeps its application rows (monitor_observation = 0) when it has any in the
-- window, and every row otherwise, so a process that owns both an app window
-- and a gesture monitor is measured by its window alone, while an explicitly
-- chosen process that only observes input still returns its observations.
-- Read the column that matches how the caller identifies its target:
--   analyzed_for_name - judged per process name, so an instance that only
--                       observed input does not rejoin a same-named instance
--                       that received the app deliveries.
--   analyzed_for_upid - judged per upid, so a caller pinned to one instance is
--                       never emptied by a same-named sibling.
-- Roles and monitor channels come from the whole relation (see
-- fragments/android_input_delivery_roles.sql); only this choice depends on the
-- window. Without action evidence anywhere in the trace no channel can be told
-- to be a monitor, so every row stays analyzed rather than guessing by name.
-- Requires fragments/android_input_delivery_roles.sql listed before it.
android_input_scoped_deliveries AS NOT MATERIALIZED (
  SELECT d.*,
    (d.monitor_observation = 0
      OR SUM(d.monitor_observation = 0) OVER (PARTITION BY d.process_name) = 0) AS analyzed_for_name,
    (d.monitor_observation = 0
      OR SUM(d.monitor_observation = 0) OVER (PARTITION BY d.upid) = 0) AS analyzed_for_upid
  FROM android_input_event_deliveries AS d
  WHERE (${start_ts} IS NULL OR d.receive_ts + d.receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR d.dispatch_ts < ${end_ts})
)
SELECT
  event_type,
  event_action,
  -- 次数/慢事件数按物理事件计，延迟逐投递。
  COUNT(DISTINCT physical_event_key) as count,
  ROUND(AVG(total_latency_dur) / 1e6, 2) as avg_latency_ms,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  COUNT(DISTINCT CASE WHEN total_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN physical_event_key END) as slow_events
FROM android_input_scoped_deliveries
WHERE process_name = '${target_process.data[0].process_name}'
  AND analyzed_for_name
GROUP BY event_type, event_action
ORDER BY avg_latency_ms DESC
