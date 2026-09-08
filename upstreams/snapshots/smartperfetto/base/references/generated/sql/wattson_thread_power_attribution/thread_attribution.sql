-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_thread_power_attribution.skill.yaml
-- Source SHA-256: 870e236f5b23da815f89f8d2d3ed6d5ca592a73f300afe43a5a1e077c7723685
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
  OR ('${package}' != '' AND ('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*'))
  OR ('${process_name}' = '' AND '${package}' = '')
)
GROUP BY process_name, thread_name
ORDER BY total_cpu_mws DESC
LIMIT ${top_n|30}
