-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_app_startup_power.skill.yaml
-- Source SHA-256: 24ebfcd8723a851df141ead1b24968cdf4a24cfba83d676f80853c803f812452
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH startup_windows AS (
  SELECT ts, dur, period_id
  FROM wattson_window_app_startup
),
startup_energy AS (
  SELECT
    period_id,
    SUM(total_mws) AS total_energy_mws
  FROM wattson_threads_aggregation!(startup_windows)
  GROUP BY period_id
)
SELECT
  s.package,
  w.ts AS window_ts,
  ROUND(w.dur / 1e6, 1) AS dur_ms,
  ROUND(COALESCE(e.total_energy_mws, 0), 2) AS total_energy_mws,
  ROUND(COALESCE(e.total_energy_mws, 0) / 3600.0, 6) AS energy_mwh,
  'wattson_thread_estimate' AS source_level
FROM startup_windows AS w
JOIN android_startups AS s
  ON s.startup_id = w.period_id
LEFT JOIN startup_energy AS e
  ON e.period_id = w.period_id
WHERE (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
ORDER BY w.ts ASC
