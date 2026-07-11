-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  COUNT(*) as pkt_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_network_packets
WHERE (package_name GLOB '${package}*' OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
