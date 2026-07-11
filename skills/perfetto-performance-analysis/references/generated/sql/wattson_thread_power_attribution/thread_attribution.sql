-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_thread_power_attribution.skill.yaml
-- Source SHA-256: 388c3628de80519709306fc275669effa48f3fe8e2cca8487bbc180070080e9a
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH window AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS ts,
    MAX(COALESCE(${end_ts}, trace_end()) - COALESCE(${start_ts}, trace_start()), 0) AS dur,
    0 AS period_id
)
SELECT
  process_name,
  thread_name,
  ROUND(SUM(total_mws), 2) AS total_cpu_mws,
  ROUND(SUM(total_mws) / 3600.0, 6) AS energy_mwh,
  ROUND(SUM(total_mws) * 1e9 / NULLIF(SUM(period_dur), 0), 2) AS avg_cpu_mw,
  'wattson_estimate' AS source_level
FROM wattson_threads_aggregation!(window)
WHERE (
  ('${process_name}' != '' AND process_name GLOB '${process_name}*')
  OR ('${package}' != '' AND process_name GLOB '${package}*')
  OR ('${process_name}' = '' AND '${package}' = '')
)
GROUP BY process_name, thread_name
ORDER BY total_cpu_mws DESC
LIMIT ${top_n|30}
