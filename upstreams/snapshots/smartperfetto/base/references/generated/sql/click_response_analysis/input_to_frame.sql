-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  ie.event_type,
  ie.event_action,
  ie.end_to_end_latency_dur / 1e6 as e2e_latency_ms,
  ie.frame_id,
  -- 关联帧信息
  af.dur / 1e6 as frame_dur_ms,
  ie.total_latency_dur / 1e6 as input_latency_ms,
  -- 输入到关联帧的延迟
  CASE
    WHEN ie.end_to_end_latency_dur / 1e6 > ${critical_event_threshold_ms|200} THEN 'critical'
    WHEN ie.end_to_end_latency_dur / 1e6 > ${slow_event_threshold_ms|100} THEN 'warning'
    WHEN ie.end_to_end_latency_dur / 1e6 > ${thread_state_min_dur_ms|50} THEN 'notice'
    ELSE 'good'
  END as rating
FROM android_input_events ie
LEFT JOIN android_frames af ON ie.frame_id = af.frame_id
WHERE ie.process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR ie.receive_ts + ie.receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR ie.dispatch_ts < ${end_ts})
  AND ie.frame_id IS NOT NULL
  AND ie.end_to_end_latency_dur > 0
ORDER BY ie.end_to_end_latency_dur DESC
LIMIT 20
