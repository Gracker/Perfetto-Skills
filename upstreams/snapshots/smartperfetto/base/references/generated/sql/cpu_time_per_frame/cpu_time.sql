-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_time_per_frame.skill.yaml
-- Source SHA-256: e9ca59dce47fb056113061c19ea44122bff0110e4f6206e0183f65bd96667e1b
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

SELECT
  frame_id,
  ROUND(cpu_time / 1e6, 2) AS cpu_time_ms
FROM android_cpu_time_per_frame
ORDER BY cpu_time DESC
LIMIT 100
