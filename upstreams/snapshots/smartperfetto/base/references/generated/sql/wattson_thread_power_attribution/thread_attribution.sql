-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_thread_power_attribution.skill.yaml
-- Source SHA-256: e22c251fa6dd0676e46b46628c57cd64a4c406774957749e51f5e1cd3233f1e5
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  process_name,
  thread_name,
  ROUND(SUM(total_mws), 2) AS total_cpu_mws,
  ROUND(SUM(total_mws) / 3600.0, 6) AS energy_mwh,
  ROUND(SUM(total_mws) * 1e9 / NULLIF(SUM(period_dur), 0), 2) AS avg_cpu_mw,
  'wattson_estimate' AS source_level
FROM wattson_threads_aggregation!((
  SELECT
    COALESCE(${start_ts}, trace_start()) AS ts,
    MAX(COALESCE(${end_ts}, trace_end()) - COALESCE(${start_ts}, trace_start()), 0) AS dur,
    0 AS period_id
))
WHERE (
  ('${process_name}' != '' AND process_name GLOB '${process_name}*')
  OR ('${package}' != '' AND process_name GLOB '${package}*')
  OR ('${process_name}' = '' AND '${package}' = '')
)
GROUP BY process_name, thread_name
ORDER BY total_cpu_mws DESC
LIMIT ${top_n|30}
