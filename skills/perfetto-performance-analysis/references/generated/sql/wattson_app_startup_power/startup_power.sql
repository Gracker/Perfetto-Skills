-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_app_startup_power.skill.yaml
-- Source SHA-256: 6e775d6b682e7adc01af41142c995bde4e5e96e428a34934a99298603c7b3ad0
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
