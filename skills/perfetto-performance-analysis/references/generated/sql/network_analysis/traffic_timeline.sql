-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

SELECT
  CAST(ts / 1000000000 AS INTEGER) as time_sec,
  SUM(packet_count) as packets_per_sec,
  ROUND(SUM(packet_length) / 1024.0, 2) as kb_per_sec,
  ROUND(SUM(CASE WHEN direction = 'Transmitted' THEN packet_length ELSE 0 END) / 1024.0, 2) as tx_kb,
  ROUND(SUM(CASE WHEN direction = 'Received' THEN packet_length ELSE 0 END) / 1024.0, 2) as rx_kb
FROM android_network_packets
WHERE (package_name GLOB '${package}*' OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY time_sec
ORDER BY time_sec
