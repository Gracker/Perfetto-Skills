-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  remote_port,
  CASE remote_port
    WHEN 80 THEN 'HTTP'
    WHEN 443 THEN 'HTTPS'
    WHEN 53 THEN 'DNS'
    WHEN 8080 THEN 'HTTP-ALT'
    WHEN 5228 THEN 'GCM/FCM'
    WHEN 5229 THEN 'GCM/FCM'
    WHEN 5230 THEN 'GCM/FCM'
    ELSE 'OTHER'
  END as service,
  COUNT(*) as event_count,
  SUM(packet_count) as total_packets,
  ROUND(SUM(packet_length) / 1024.0, 2) as total_kb
FROM android_network_packets
WHERE remote_port IS NOT NULL
  AND (package_name GLOB '${package}*' OR '${package}' = '')
  AND (iface GLOB '*${interface}*' OR '${interface}' = '')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY remote_port
ORDER BY total_kb DESC
LIMIT 20
