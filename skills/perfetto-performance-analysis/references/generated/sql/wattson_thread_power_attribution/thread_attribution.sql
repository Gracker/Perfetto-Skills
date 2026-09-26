-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_thread_power_attribution.skill.yaml
-- Source SHA-256: 49ff2d97a1fea4715446fa98199ac53849fd826e1c0cacf1d8e85bf9700c1a30
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
  ('${process_name}' != '' AND (process_name = '${process_name}' OR process_name GLOB '${process_name}:*'))
  OR ('${package}' != '' AND ('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*'))
  OR ('${process_name}' = '' AND '${package}' = '')
)
GROUP BY process_name, thread_name
ORDER BY total_cpu_mws DESC
LIMIT ${top_n|30}
