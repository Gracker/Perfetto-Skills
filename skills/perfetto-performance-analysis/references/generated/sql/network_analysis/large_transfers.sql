-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 390c291f6c2a0149d466965148a169836930c1d3393129ea790511f28db54319

SELECT
  printf('%d', ts) as event_ts,
  package_name,
  iface,
  direction,
  packet_transport,
  packet_count,
  ROUND(packet_length / 1024.0, 2) as kb
FROM android_network_packets
WHERE (('${package}' = '' OR package_name = '${package}' OR package_name GLOB '${package}:*') OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY packet_length DESC
LIMIT 20
