-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  printf('%d', ts) as event_ts,
  package_name,
  iface,
  direction,
  packet_transport,
  packet_count,
  ROUND(packet_length / 1024.0, 2) as kb
FROM android_network_packets
WHERE (package_name GLOB '${package}*' OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY packet_length DESC
LIMIT 20
