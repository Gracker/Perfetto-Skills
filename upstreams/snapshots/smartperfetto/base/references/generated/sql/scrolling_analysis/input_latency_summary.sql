-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: b7ebca89bd8e31ada9de2d388e0e3cd9e257c8ef65e1c0e6862c167bc631da67
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

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
,
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
timing_config AS (
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
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
scoped_events AS (
  SELECT *
  FROM android_input_event_deliveries
  WHERE (${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid})
    AND (
    ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR process_name = '${package}'
    OR process_name GLOB '${package}:*'
  )
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
),
-- 同一物理事件的 monitor 副本不算应用投递；显式 upid/package 已在 scoped_events 收窄候选。
ranked_processes AS (
  SELECT
    upid, process_name,
    ROW_NUMBER() OVER (ORDER BY
      SUM(delivery_role = 'action') DESC,
      COUNT(DISTINCT unresolved_event_key) DESC,
      MAX(total_latency_dur) DESC, upid) as rn
  FROM scoped_events
  GROUP BY upid, process_name
),
target AS (
  SELECT upid, process_name
  FROM ranked_processes
  WHERE rn = 1
),
target_events AS (
  SELECT e.*
  FROM scoped_events e
  JOIN target t ON e.upid = t.upid
),
-- A speculative association is only the next doFrame on the receiving
-- thread, not proof the frame consumed the event; backlog counts exact ones.
frame_backlog AS (
  SELECT frame_id, COUNT(*) as event_count
  FROM target_events
  WHERE frame_id IS NOT NULL AND COALESCE(is_speculative_frame, 0) = 0
  GROUP BY frame_id
)
SELECT
  (SELECT process_name FROM target) as target_process,
  COUNT(*) as total_input_events,
  SUM(CASE WHEN event_action = 'MOVE' THEN 1 ELSE 0 END) as move_events,
  ROUND(AVG(dispatch_latency_dur) / 1e6, 2) as avg_dispatch_ms,
  ROUND(MAX(dispatch_latency_dur) / 1e6, 2) as max_dispatch_ms,
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  ROUND(PERCENTILE(handling_latency_dur, 95) / 1e6, 2) as p95_handling_ms,
  ROUND(MAX(handling_latency_dur) / 1e6, 2) as max_handling_ms,
  ROUND(AVG(ack_latency_dur) / 1e6, 2) as avg_ack_ms,
  ROUND(MAX(ack_latency_dur) / 1e6, 2) as max_ack_ms,
  ROUND(AVG(end_to_end_latency_dur) / 1e6, 2) as avg_e2e_ms,
  ROUND(MAX(end_to_end_latency_dur) / 1e6, 2) as max_e2e_ms,
  SUM(CASE
    WHEN handling_latency_dur > (SELECT vsync_period_ns FROM timing_config) * ${input_handling_budget_ratio|0.5}
    THEN 1 ELSE 0 END) as slow_handling_events,
  (SELECT COUNT(*) FROM frame_backlog WHERE event_count >= ${input_event_backlog_threshold|3}) as input_backlog_frames,
  SUM(CASE WHEN is_speculative_frame = 1 THEN 1 ELSE 0 END) as speculative_frame_matches,
  ROUND((SELECT vsync_period_ns FROM timing_config) / 1e6, 2) as frame_budget_ms,
  CASE
    WHEN COUNT(*) = 0 THEN '无 input 事件'
    WHEN SUM(CASE WHEN handling_latency_dur > (SELECT vsync_period_ns FROM timing_config) * ${input_handling_budget_ratio|0.5} THEN 1 ELSE 0 END) = 0 THEN '正常'
    WHEN MAX(handling_latency_dur) > (SELECT vsync_period_ns FROM timing_config) * 2 THEN '严重'
    ELSE '需关注'
  END as input_latency_rating
FROM target_events
