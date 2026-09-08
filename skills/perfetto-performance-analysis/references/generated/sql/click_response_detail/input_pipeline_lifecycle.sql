-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 051bdc9c5edc28e6120e77e34dfa9036ffbfc5b1c4ea529604ca31a7435714b5
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

-- 父 Skill 直接传入 android_input_events 的精确事件边界；不猜测相邻事件。
-- Frame 阶段自 Perfetto 7b573c1 起由 _android_input_frames 扩展提供。
WITH target_event AS (
  SELECT *
  FROM android_input_events
  WHERE process_name = '${process_name}'
    AND dispatch_ts = ${event_ts}
    AND receive_ts + receive_dur = ${event_end_ts}
  ORDER BY input_event_id, event_channel
  LIMIT 1
)
SELECT
  e.input_event_id as input_id,
  e.event_channel as channel,
  ROUND(e.end_to_end_latency_dur / 1e6, 2) as total_latency_ms,
  CASE WHEN e.read_time IS NOT NULL THEN printf('%d', e.read_time) END as reader_ts,
  ROUND(s_read.dur / 1e6, 2) as reader_ms,
  CASE WHEN e.dispatch_ts IS NOT NULL THEN printf('%d', e.dispatch_ts) END as dispatch_ts,
  ROUND(s_dispatch.dur / 1e6, 2) as dispatch_ms,
  CASE WHEN e.receive_ts IS NOT NULL THEN printf('%d', e.receive_ts) END as receive_ts,
  ROUND(s_receive.dur / 1e6, 2) as receive_ms,
  CASE WHEN s_consume.ts IS NOT NULL THEN printf('%d', s_consume.ts) END as consume_ts,
  ROUND(s_consume.dur / 1e6, 2) as consume_ms,
  CASE WHEN frames.ts_do_frame IS NOT NULL THEN printf('%d', frames.ts_do_frame) END as frame_ts,
  ROUND(frames.dur_do_frame / 1e6, 2) as frame_ms,
  e.is_speculative_frame
FROM target_event e
LEFT JOIN slice s_read
  ON s_read.ts = e.read_time
  AND s_read.track_id != 0
  AND s_read.name GLOB 'UnwantedInteractionBlocker::notifyMotion*'
LEFT JOIN slice s_dispatch
  ON s_dispatch.ts = e.dispatch_ts
  AND s_dispatch.track_id = e.dispatch_track_id
LEFT JOIN slice s_receive
  ON s_receive.ts = e.receive_ts
  AND s_receive.track_id = e.receive_track_id
LEFT JOIN _input_consumers_lookup s_consume
  ON s_consume.cookie = e.event_seq
LEFT JOIN _android_input_frames frames
  ON frames.frame_id = e.frame_id
  AND frames.upid = e.upid
