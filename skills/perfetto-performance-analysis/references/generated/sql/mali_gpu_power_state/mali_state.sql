-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/mali_gpu_power_state.skill.yaml
-- Source SHA-256: 2846582cac7aa964a047a495575cb21b1517b7d63bf7d6bc261baf43847ed6db
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT
  ts,
  ROUND(dur / 1e6, 2) AS dur_ms,
  power_state
FROM android_mali_gpu_power_state
ORDER BY ts ASC
