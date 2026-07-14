-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_rails_power_breakdown.skill.yaml
-- Source SHA-256: 9e2ae8ad5f92ade41fd691813c04bca6d79989977357e0f8f778201ac65a98bf
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  subsystem,
  breakdown_type,
  COALESCE(CAST(component_id AS STRING), '') AS component_id,
  ROUND(SUM(estimated_mws), 2) AS total_energy_mws,
  ROUND(SUM(estimated_mws) / 3600.0, 6) AS energy_mwh,
  ROUND(SUM(estimated_mws) * 1e9 / NULLIF(SUM(period_dur), 0), 2) AS avg_power_mw,
  'wattson_estimate' AS source_level
FROM wattson_rails_aggregation!((
  SELECT
    COALESCE(${start_ts}, trace_start()) AS ts,
    MAX(COALESCE(${end_ts}, trace_end()) - COALESCE(${start_ts}, trace_start()), 0) AS dur,
    0 AS period_id
))
GROUP BY subsystem, breakdown_type, component_id
ORDER BY total_energy_mws DESC
LIMIT ${top_n|20}
