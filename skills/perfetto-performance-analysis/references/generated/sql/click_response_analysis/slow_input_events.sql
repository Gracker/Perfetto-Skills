-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  event_type,
  event_action,
  event_channel,
  normalized_event_channel as normalized_channel,
  ROUND(total_latency_dur / 1e6, 2) as total_ms,
  ROUND(dispatch_latency_dur / 1e6, 2) as dispatch_ms,
  ROUND(handling_latency_dur / 1e6, 2) as handling_ms,
  ROUND(ack_latency_dur / 1e6, 2) as ack_ms,
  ROUND(end_to_end_latency_dur / 1e6, 2) as e2e_ms,
  thread_name,
  process_name,
  frame_id,
  -- 时间戳用于详细分析
  printf('%d', dispatch_ts) as event_ts,
  printf('%d', receive_ts + receive_dur) as event_end_ts,
  -- Perfetto 跳转参数（前后各扩展 20ms）
  printf('%d', CAST(dispatch_ts - 20000000 AS INTEGER)) as perfetto_start,
  printf('%d', CAST(receive_ts + receive_dur + 20000000 AS INTEGER)) as perfetto_end,
  CASE
    WHEN total_latency_dur / 1e6 > ${critical_event_threshold_ms|200} THEN 'critical'
    WHEN total_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN 'warning'
    ELSE 'notice'
  END as severity,
  -- 延迟主要来源
  CASE
    WHEN dispatch_latency_dur > handling_latency_dur AND dispatch_latency_dur > ack_latency_dur THEN '系统分发'
    WHEN handling_latency_dur > ack_latency_dur THEN '应用处理'
    ELSE 'ACK'
  END as main_bottleneck
FROM android_input_events
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
  AND total_latency_dur > ${slow_event_threshold_ms|100} * 1000000  -- > slow threshold
ORDER BY total_latency_dur DESC
LIMIT 20
