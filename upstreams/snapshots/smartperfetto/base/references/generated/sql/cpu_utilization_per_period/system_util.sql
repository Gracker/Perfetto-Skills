-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_utilization_per_period.skill.yaml
-- Source SHA-256: 9920c14a1dfb568ab235f8ad07dc05900335274cf3a7715383808227764b30a7
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  ts,
  100.0 AS dur_ms,
  ROUND(utilization, 4) AS utilization
FROM cpu_utilization_per_period(time_from_ms(100))
ORDER BY ts ASC
