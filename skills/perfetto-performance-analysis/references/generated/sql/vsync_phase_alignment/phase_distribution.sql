-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_phase_alignment.skill.yaml
-- Source SHA-256: afb3392a3d6d5a71d05ce84f94211a80757acc455aa358519c129b83436c9560
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
vsync_events AS (
  SELECT c.ts as vsync_ts
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
input_events AS (
  SELECT dispatch_ts as input_ts
  FROM android_input_events_normalized
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
),
phase_offsets AS (
  SELECT
    (ie.input_ts - (SELECT MAX(v.vsync_ts) FROM vsync_events v WHERE v.vsync_ts <= ie.input_ts)) as offset_ns,
    ((SELECT MIN(v.vsync_ts) FROM vsync_events v WHERE v.vsync_ts > ie.input_ts) - ie.input_ts) as wait_ns
  FROM input_events ie
),
valid AS (
  SELECT offset_ns, wait_ns FROM phase_offsets
  WHERE offset_ns IS NOT NULL AND wait_ns IS NOT NULL
    AND offset_ns >= 0 AND wait_ns >= 0
)
SELECT '相位偏移 P50(ms)' as metric, CAST(ROUND(PERCENTILE(offset_ns, 50) / 1e6, 2) AS TEXT) as value FROM valid
UNION ALL
SELECT '相位偏移 P90(ms)', CAST(ROUND(PERCENTILE(offset_ns, 90) / 1e6, 2) AS TEXT) FROM valid
UNION ALL
SELECT 'VSync等待 P50(ms)', CAST(ROUND(PERCENTILE(wait_ns, 50) / 1e6, 2) AS TEXT) FROM valid
UNION ALL
SELECT 'VSync等待 P90(ms)', CAST(ROUND(PERCENTILE(wait_ns, 90) / 1e6, 2) AS TEXT) FROM valid
UNION ALL
SELECT '偏移>75%周期(不利相位)', CAST(ROUND(
  100.0 * (SELECT COUNT(*) FROM valid WHERE offset_ns > (SELECT period_ns FROM vsync_cfg) * 0.75) /
  MAX((SELECT COUNT(*) FROM valid), 1), 1) AS TEXT) || '%' FROM valid
UNION ALL
SELECT '样本数', CAST(COUNT(*) AS TEXT) FROM valid
