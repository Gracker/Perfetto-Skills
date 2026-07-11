-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  COUNT(*) as total_events,
  SUM(packet_count) as total_packets,
  ROUND(SUM(packet_length) / 1024.0, 2) as total_kb,
  ROUND(SUM(packet_length) / 1024.0 / 1024.0, 2) as total_mb,
  SUM(CASE WHEN direction = 'Transmitted' THEN packet_count ELSE 0 END) as tx_packets,
  SUM(CASE WHEN direction = 'Received' THEN packet_count ELSE 0 END) as rx_packets,
  ROUND(SUM(CASE WHEN direction = 'Transmitted' THEN packet_length ELSE 0 END) / 1024.0, 2) as tx_kb,
  ROUND(SUM(CASE WHEN direction = 'Received' THEN packet_length ELSE 0 END) / 1024.0, 2) as rx_kb,
  CASE
    WHEN SUM(packet_length) / 1024.0 / 1024.0 > 100 THEN '流量大'
    WHEN SUM(packet_length) / 1024.0 / 1024.0 > 10 THEN '中等'
    ELSE '正常'
  END as rating
FROM android_network_packets
WHERE (package_name GLOB '${package}*' OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
