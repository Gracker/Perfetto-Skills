-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/process_thread_wait_sources_in_range.skill.yaml
-- Source SHA-256: 61e2aa322937a94978c62f45418e45cb8ae7f2efd784c0e6fde242f860fdae8c

SELECT
  COUNT(*) AS rx_packet_rows,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END AS status
FROM android_network_packets
WHERE direction = 'Received'
  AND ts < ${end_ts}
  AND ts + MAX(dur, 0) > ${start_ts}
