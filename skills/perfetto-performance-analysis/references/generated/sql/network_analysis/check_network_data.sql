-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: b0d6f1c51fe5e8687db9cc5ec9b1df231029151ee389c92bfb42f096e1ac13e0

SELECT
  COUNT(*) as pkt_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM android_network_packets
WHERE (('${package}' = '' OR package_name = '${package}' OR package_name GLOB '${package}:*') OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
