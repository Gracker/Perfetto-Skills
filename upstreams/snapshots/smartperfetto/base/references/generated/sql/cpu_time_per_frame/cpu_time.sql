-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_time_per_frame.skill.yaml
-- Source SHA-256: e9ca59dce47fb056113061c19ea44122bff0110e4f6206e0183f65bd96667e1b
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  frame_id,
  ROUND(cpu_time / 1e6, 2) AS cpu_time_ms
FROM android_cpu_time_per_frame
ORDER BY cpu_time DESC
LIMIT 100
