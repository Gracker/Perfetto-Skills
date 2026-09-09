-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 42f8702c1c1ee5326dedc0ff19beacffefd3055ddb59008ef90b81049c3c5d1e
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  COUNT(*) as pkt_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_network_packets
WHERE (('${package}' = '' OR package_name = '${package}' OR package_name GLOB '${package}:*') OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
