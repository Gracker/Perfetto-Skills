-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/modem_network_correlation_summary.skill.yaml
-- Source SHA-256: 7cca2aaa1525cb329a14c22261e7c4fb8365284a7410d31bb6d9605950895a47
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS start_ts,
    COALESCE(${end_ts}, trace_end()) AS end_ts
),
modem_rails AS (
  SELECT
    SUM(c.average_power * (
      MIN(c.ts + c.dur, b.end_ts) - MAX(c.ts, b.start_ts)
    ) / 1e6) AS energy_uws
  FROM android_power_rails_counters c
  LEFT JOIN android_power_rails_metadata m USING (track_id)
  CROSS JOIN bounds b
  WHERE c.ts < b.end_ts
    AND c.ts + c.dur > b.start_ts
    AND (
      LOWER(COALESCE(c.power_rail_name, '')) GLOB '*modem*'
      OR LOWER(COALESCE(c.power_rail_name, '')) GLOB '*cell*'
      OR LOWER(COALESCE(c.power_rail_name, '')) GLOB '*radio*'
      OR LOWER(COALESCE(c.raw_power_rail_name, '')) GLOB '*modem*'
      OR LOWER(COALESCE(c.raw_power_rail_name, '')) GLOB '*cell*'
      OR LOWER(COALESCE(c.raw_power_rail_name, '')) GLOB '*radio*'
      OR LOWER(COALESCE(m.subsystem_name, '')) GLOB '*modem*'
      OR LOWER(COALESCE(m.subsystem_name, '')) GLOB '*cell*'
      OR LOWER(COALESCE(m.subsystem_name, '')) GLOB '*radio*'
    )
),
cellular_packets AS (
  SELECT
    package_name,
    socket_uid,
    socket_tag,
    ts,
    dur,
    packet_count,
    packet_length
  FROM android_network_packets, bounds
  WHERE ts >= start_ts
    AND ts < end_ts
    AND (
      iface GLOB 'rmnet*'
      OR iface GLOB 'ccmni*'
      OR iface GLOB 'wwan*'
      OR iface GLOB 'cell*'
      OR LOWER(track_name) GLOB '*cell*'
      OR LOWER(track_name) GLOB '*mobile*'
      OR LOWER(track_name) GLOB '*modem*'
    )
),
uptime AS (
  SELECT *
  FROM android_network_uptime_spans!(
    (
      SELECT
        package_name,
        socket_uid,
        socket_tag,
        ts,
        dur,
        packet_count,
        packet_length
      FROM cellular_packets
    ),
    (package_name, socket_uid, socket_tag),
    10000000000
  )
),
ranked AS (
  SELECT
    package_name,
    socket_uid,
    socket_tag,
    SUM(packet_count) AS packet_count,
    SUM(packet_length) AS bytes,
    ROUND(SUM(dur) / 1e9, 2) AS cellular_uptime_sec,
    ROUND((SELECT energy_uws FROM modem_rails) / 3.6e9, 6) AS modem_energy_mwh,
    CASE
      WHEN COALESCE((SELECT energy_uws FROM modem_rails), 0) > 0 THEN 'correlation_only_with_modem_rail'
      ELSE 'network_only_no_modem_rail'
    END AS confidence
  FROM uptime
  GROUP BY package_name, socket_uid, socket_tag
  ORDER BY bytes DESC
  LIMIT ${top_n|20}
)
SELECT * FROM ranked
UNION ALL
SELECT
  '' AS package_name,
  NULL AS socket_uid,
  '' AS socket_tag,
  0 AS packet_count,
  0 AS bytes,
  0 AS cellular_uptime_sec,
  ROUND((SELECT energy_uws FROM modem_rails) / 3.6e9, 6) AS modem_energy_mwh,
  CASE
    WHEN COALESCE((SELECT energy_uws FROM modem_rails), 0) > 0 THEN 'modem_rail_without_cellular_packets'
    ELSE 'insufficient_modem_and_cellular_data'
  END AS confidence
WHERE NOT EXISTS (SELECT 1 FROM ranked)
