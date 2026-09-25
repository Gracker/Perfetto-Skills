-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/process_thread_wait_sources_in_range.skill.yaml
-- Source SHA-256: a63b33f91c961cf74a88510339a24499fc5a04d98ba04563ebe10ddd9bfc76e1
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

SELECT
  COUNT(*) AS rx_packet_rows,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END AS status
FROM android_network_packets
WHERE direction = 'Received'
  AND ts < ${end_ts}
  AND ts + MAX(dur, 0) > ${start_ts}
