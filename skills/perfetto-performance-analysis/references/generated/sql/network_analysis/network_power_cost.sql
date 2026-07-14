-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH filtered_packets AS (
  SELECT *
  FROM android_network_packets
  WHERE (package_name GLOB '${package}*' OR '${package}' = '')
    AND (iface GLOB '*${interface}*' OR '${interface}' = '')
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
uptime_spans AS (
  SELECT *
  FROM android_network_uptime_spans!(
    filtered_packets,
    (iface),
    10000000000
  )
)
SELECT
  iface,
  COUNT(*) as active_periods,
  ROUND(SUM(dur) / 1e9, 2) as total_active_sec,
  ROUND(AVG(dur) / 1e9, 2) as avg_active_sec,
  SUM(packet_count) as total_packets,
  ROUND(SUM(packet_length) / 1024.0 / 1024.0, 2) as total_mb
FROM uptime_spans
GROUP BY iface
ORDER BY total_active_sec DESC
