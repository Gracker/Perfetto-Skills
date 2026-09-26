-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 42ded4806d9a910a2d97e2c7894bbdc986e7195a4ed6d85a2ee0fa43c4ae4dfd
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
scoped AS (
  SELECT exact_end_to_end_latency_dur, frame_association
  FROM android_input_events_normalized
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
),
-- exact association only (see fragments/android_input_events_normalized.sql); speculative counted separately.
valid AS (
  SELECT exact_end_to_end_latency_dur as latency_ns
  FROM scoped
  WHERE exact_end_to_end_latency_dur > 0
    AND exact_end_to_end_latency_dur < 500000000
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
SELECT '推测关联事件数', CAST(COUNT(*) AS REAL) FROM scoped WHERE frame_association = 'speculative'
UNION ALL
SELECT 'VSync周期(ms)', ROUND((SELECT period_ns FROM vsync_cfg) / 1e6, 2) FROM valid LIMIT 1
