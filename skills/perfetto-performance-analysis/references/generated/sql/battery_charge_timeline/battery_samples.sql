-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/battery_charge_timeline.skill.yaml
-- Source SHA-256: f2c833e0011fe26b5fa5876a09017049993e4ccd8fb399900e18e730417a037b
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  ts,
  capacity_percent AS capacity_pct,
  charge_uah,
  voltage_uv,
  current_ua
FROM android_battery_charge
WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC
