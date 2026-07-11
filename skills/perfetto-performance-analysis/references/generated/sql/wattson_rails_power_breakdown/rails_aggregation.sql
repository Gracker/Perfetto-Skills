-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_rails_power_breakdown.skill.yaml
-- Source SHA-256: 8214b9e8c26e8130521fe0d2665da06cf7fa7d139bddbcd0a6f83543d3c09bdb
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH window AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS ts,
    MAX(COALESCE(${end_ts}, trace_end()) - COALESCE(${start_ts}, trace_start()), 0) AS dur,
    0 AS period_id
)
SELECT
  subsystem,
  breakdown_type,
  COALESCE(CAST(component_id AS STRING), '') AS component_id,
  ROUND(SUM(estimated_mws), 2) AS total_energy_mws,
  ROUND(SUM(estimated_mws) / 3600.0, 6) AS energy_mwh,
  ROUND(SUM(estimated_mws) * 1e9 / NULLIF(SUM(period_dur), 0), 2) AS avg_power_mw,
  'wattson_estimate' AS source_level
FROM wattson_rails_aggregation!(window)
GROUP BY subsystem, breakdown_type, component_id
ORDER BY total_energy_mws DESC
LIMIT ${top_n|20}
