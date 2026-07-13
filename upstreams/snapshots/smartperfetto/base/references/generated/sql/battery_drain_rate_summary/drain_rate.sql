-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/battery_drain_rate_summary.skill.yaml
-- Source SHA-256: f5a1df9c8222d32c6942df42bb1bbde8dc81f44d1b7cd23ea41aed8897bda582
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH samples AS (
  SELECT *
  FROM android_battery_charge
  WHERE ts >= COALESCE(${start_ts}, trace_start())
    AND ts < COALESCE(${end_ts}, trace_end())
),
ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (ORDER BY ts ASC) AS rn_first,
    ROW_NUMBER() OVER (ORDER BY ts DESC) AS rn_last
  FROM samples
),
summary AS (
  SELECT
    COUNT(*) AS sample_count,
    MIN(ts) AS first_ts,
    MAX(ts) AS last_ts,
    MAX(CASE WHEN rn_first = 1 THEN capacity_percent END) AS first_capacity_pct,
    MAX(CASE WHEN rn_last = 1 THEN capacity_percent END) AS last_capacity_pct,
    MAX(CASE WHEN rn_first = 1 THEN charge_uah END) AS first_charge_uah,
    MAX(CASE WHEN rn_last = 1 THEN charge_uah END) AS last_charge_uah,
    AVG(current_ua) AS avg_current_ua,
    AVG(current_avg_ua) AS avg_current_avg_ua,
    AVG(voltage_uv) AS avg_voltage_uv,
    AVG(power_mw) AS avg_power_mw,
    SUM(CASE WHEN current_ua > 0 OR current_avg_ua > 0 THEN 1 ELSE 0 END) AS positive_current_samples
  FROM ranked
)
SELECT
  sample_count,
  ROUND((last_ts - first_ts) / 1e9, 2) AS duration_sec,
  ROUND(first_capacity_pct - last_capacity_pct, 4) AS capacity_delta_pct,
  ROUND((first_capacity_pct - last_capacity_pct) * 3600.0 / NULLIF((last_ts - first_ts) / 1e9, 0), 4) AS drain_pct_per_hour,
  ROUND(first_charge_uah - last_charge_uah, 2) AS charge_delta_uah,
  ROUND(COALESCE(avg_current_avg_ua, avg_current_ua), 2) AS avg_current_ua,
  ROUND(avg_voltage_uv, 2) AS avg_voltage_uv,
  ROUND(avg_power_mw, 2) AS avg_power_mw,
  CASE
    WHEN sample_count < 2 THEN 'insufficient_samples'
    WHEN positive_current_samples > 0 THEN 'charging_or_usb_detected'
    ELSE 'discharging_or_unknown_sign'
  END AS charging_state,
  'battery_counter_trend' AS source_level
FROM summary
