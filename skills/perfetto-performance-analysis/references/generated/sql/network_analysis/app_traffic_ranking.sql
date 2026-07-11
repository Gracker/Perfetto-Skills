-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  package_name,
  direction,
  COUNT(*) as event_count,
  SUM(packet_count) as total_packets,
  ROUND(SUM(packet_length) / 1024.0, 2) as total_kb
FROM android_network_packets
WHERE (package_name GLOB '${package}*' OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY package_name, direction
ORDER BY total_kb DESC
LIMIT 30
