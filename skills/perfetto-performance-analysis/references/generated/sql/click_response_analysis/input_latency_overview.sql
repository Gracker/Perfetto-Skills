-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: c36d5e8f865c21530d0538a9a549cc6cacafc1b68da63ba7f2d6e83052d6a08f
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  COUNT(*) as total_events,
  -- 分发延迟（系统责任）
  ROUND(AVG(dispatch_latency_dur) / 1e6, 2) as avg_dispatch_ms,
  ROUND(MAX(dispatch_latency_dur) / 1e6, 2) as max_dispatch_ms,
  -- 处理延迟（应用责任）
  ROUND(AVG(handling_latency_dur) / 1e6, 2) as avg_handling_ms,
  ROUND(MAX(handling_latency_dur) / 1e6, 2) as max_handling_ms,
  -- ACK 延迟
  ROUND(AVG(ack_latency_dur) / 1e6, 2) as avg_ack_ms,
  -- dispatch-to-ACK 总延迟
  ROUND(AVG(total_latency_dur) / 1e6, 2) as avg_total_ms,
  ROUND(MAX(total_latency_dur) / 1e6, 2) as max_total_ms,
  -- 输入到关联帧延迟（需要 frame_id/FrameTimeline）
  ROUND(AVG(end_to_end_latency_dur) / 1e6, 2) as avg_e2e_ms,
  ROUND(MAX(end_to_end_latency_dur) / 1e6, 2) as max_e2e_ms,
  -- 评级
  CASE
    WHEN AVG(total_latency_dur) / 1e6 < 50 THEN '优秀 (<50ms)'
    WHEN AVG(total_latency_dur) / 1e6 < ${slow_event_threshold_ms|100} THEN '良好 (50-100ms)'
    WHEN AVG(total_latency_dur) / 1e6 < ${critical_event_threshold_ms|200} THEN '可接受 (100-200ms)'
    ELSE '较差 (>200ms)'
  END as rating
FROM android_input_events
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
