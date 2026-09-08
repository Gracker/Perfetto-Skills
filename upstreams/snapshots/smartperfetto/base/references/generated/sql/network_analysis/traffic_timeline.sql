-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 42f8702c1c1ee5326dedc0ff19beacffefd3055ddb59008ef90b81049c3c5d1e
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  CAST(ts / 1000000000 AS INTEGER) as time_sec,
  SUM(packet_count) as packets_per_sec,
  ROUND(SUM(packet_length) / 1024.0, 2) as kb_per_sec,
  ROUND(SUM(CASE WHEN direction = 'Transmitted' THEN packet_length ELSE 0 END) / 1024.0, 2) as tx_kb,
  ROUND(SUM(CASE WHEN direction = 'Received' THEN packet_length ELSE 0 END) / 1024.0, 2) as rx_kb
FROM android_network_packets
WHERE (('${package}' = '' OR package_name = '${package}' OR package_name GLOB '${package}:*') OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY time_sec
ORDER BY time_sec
