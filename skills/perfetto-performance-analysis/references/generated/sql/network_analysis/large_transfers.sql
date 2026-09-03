-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 42f8702c1c1ee5326dedc0ff19beacffefd3055ddb59008ef90b81049c3c5d1e
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
