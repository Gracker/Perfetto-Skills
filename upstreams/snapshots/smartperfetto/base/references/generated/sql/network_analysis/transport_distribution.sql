-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 42f8702c1c1ee5326dedc0ff19beacffefd3055ddb59008ef90b81049c3c5d1e
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

SELECT
  packet_transport,
  COUNT(*) as event_count,
  SUM(packet_count) as total_packets,
  ROUND(SUM(packet_length) / 1024.0, 2) as total_kb
FROM android_network_packets
WHERE (('${package}' = '' OR package_name = '${package}' OR package_name GLOB '${package}:*') OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY packet_transport
ORDER BY total_kb DESC
