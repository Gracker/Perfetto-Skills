-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_time_per_frame.skill.yaml
-- Source SHA-256: e9ca59dce47fb056113061c19ea44122bff0110e4f6206e0183f65bd96667e1b
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT
  frame_id,
  ROUND(cpu_time / 1e6, 2) AS cpu_time_ms
FROM android_cpu_time_per_frame
ORDER BY cpu_time DESC
LIMIT 100
