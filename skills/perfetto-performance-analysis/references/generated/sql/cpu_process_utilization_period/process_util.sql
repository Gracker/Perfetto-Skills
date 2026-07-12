-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
-- Source SHA-256: 396d2f22f5fc3e74c65a12e598742afe1da04e59b47ac29093992f3d2938038b
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  process_name,
  ROUND(utilization, 4) AS utilization
FROM cpu_process_utilization_per_period
ORDER BY utilization DESC
LIMIT 30
