-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: c36d5e8f865c21530d0538a9a549cc6cacafc1b68da63ba7f2d6e83052d6a08f
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  CASE
    WHEN total_latency_dur / 1e6 < 16 THEN '<16ms (极快)'
    WHEN total_latency_dur / 1e6 < 50 THEN '16-50ms (快)'
    WHEN total_latency_dur / 1e6 < 100 THEN '50-100ms (正常)'
    WHEN total_latency_dur / 1e6 < 200 THEN '100-200ms (慢)'
    ELSE '>200ms (很慢)'
  END as latency_bucket,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / (
    SELECT COUNT(*) FROM android_input_events
    WHERE process_name = '${target_process.data[0].process_name}'
      AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
      AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
  ), 1) as percent
FROM android_input_events
WHERE process_name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
  AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
GROUP BY latency_bucket
ORDER BY
  CASE latency_bucket
    WHEN '<16ms (极快)' THEN 1
    WHEN '16-50ms (快)' THEN 2
    WHEN '50-100ms (正常)' THEN 3
    WHEN '100-200ms (慢)' THEN 4
    ELSE 5
  END
