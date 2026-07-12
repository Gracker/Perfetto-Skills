-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wattson_app_startup_power.skill.yaml
-- Source SHA-256: 306e55087c67e9f4fe2d3c6bf37e5372a3ed7019c0470eb97e07921adf210f1f
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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
WHERE (s.package GLOB '${package}*' OR '${package}' = '')
ORDER BY w.ts ASC
