-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 3bf411e6c0f6db9de2434fb0ad420cb0a0140388c5968306f5ad569b3ff0c3e7
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

-- 从 deliverInputEvent slice 反向追踪完整输入管线
-- 注意：时间窗口匹配在事件密集场景下可能绑错事件，click 场景通常事件稀疏
WITH deliver_slice AS (
  SELECT s.id
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE s.name GLOB 'deliverInputEvent src=*'
    AND p.name GLOB '${process_name}*'
    AND s.ts >= ${event_ts} - 10000000
    AND s.ts <= ${event_end_ts} + 10000000
  ORDER BY s.ts
  LIMIT 1
)
SELECT
  input_id,
  channel,
  ROUND(total_latency / 1e6, 2) as total_latency_ms,
  printf('%d', ts_reader) as reader_ts,
  ROUND(dur_reader / 1e6, 2) as reader_ms,
  printf('%d', ts_dispatch) as dispatch_ts,
  ROUND(dur_dispatch / 1e6, 2) as dispatch_ms,
  printf('%d', ts_receive) as receive_ts,
  ROUND(dur_receive / 1e6, 2) as receive_ms,
  printf('%d', ts_consume) as consume_ts,
  ROUND(dur_consume / 1e6, 2) as consume_ms,
  printf('%d', ts_frame) as frame_ts,
  ROUND(dur_frame / 1e6, 2) as frame_ms,
  is_speculative_frame
FROM _android_input_lifecycle_by_slice_id((SELECT id FROM deliver_slice))
