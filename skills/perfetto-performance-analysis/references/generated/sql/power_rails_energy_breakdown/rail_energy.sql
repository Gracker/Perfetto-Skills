-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/power_rails_energy_breakdown.skill.yaml
-- Source SHA-256: 6aaff1c3c000fd17b55820ae6849ffcf6d24beb72dd5a902f08144738181563f
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS start_ts,
    COALESCE(${end_ts}, trace_end()) AS end_ts
),
clipped AS (
  SELECT
    c.power_rail_name,
    c.raw_power_rail_name,
    COALESCE(m.subsystem_name, '') AS subsystem_name,
    c.average_power,
    MIN(c.ts + c.dur, b.end_ts) - MAX(c.ts, b.start_ts) AS clipped_dur
  FROM android_power_rails_counters c
  LEFT JOIN android_power_rails_metadata m USING (track_id)
  CROSS JOIN bounds b
  WHERE c.ts < b.end_ts
    AND c.ts + c.dur > b.start_ts
),
window AS (
  SELECT MAX(end_ts - start_ts, 0) AS window_dur
  FROM bounds
),
energy AS (
  SELECT
    power_rail_name,
    raw_power_rail_name,
    subsystem_name,
    SUM(average_power * clipped_dur / 1e6) AS energy_uws,
    SUM(clipped_dur) AS covered_dur
  FROM clipped
  WHERE clipped_dur > 0
  GROUP BY power_rail_name, raw_power_rail_name, subsystem_name
)
SELECT
  power_rail_name,
  subsystem_name,
  raw_power_rail_name,
  ROUND(energy_uws, 2) AS energy_uws,
  ROUND(energy_uws / 3.6e9, 6) AS energy_mwh,
  ROUND(energy_uws * 1e6 / NULLIF((SELECT window_dur FROM window), 0), 2) AS avg_power_mw,
  ROUND(covered_dur * 100.0 / NULLIF((SELECT window_dur FROM window), 0), 2) AS sample_coverage_pct,
  'hardware_power_rails' AS source_level
FROM energy
ORDER BY energy_uws DESC
LIMIT ${top_n|30}
