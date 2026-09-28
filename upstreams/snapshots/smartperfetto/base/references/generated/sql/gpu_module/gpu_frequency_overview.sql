-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/gpu_module.skill.yaml
-- Source SHA-256: 6dd740df9f3de46527f96908cf6ac30d71767e6f61d2bc2d6544f825cbbc3551
-- Source commit: 42ef4dd2878646bf238a54d53c934d4d4f3e4b3f

SELECT
  track.name AS counter_name,
  CAST(AVG(value) AS INTEGER) AS avg_value,
  CAST(MAX(value) AS INTEGER) AS max_value,
  CAST(MIN(value) AS INTEGER) AS min_value
FROM counter
JOIN gpu_counter_track track ON counter.track_id = track.id
WHERE track.name LIKE '%freq%' OR track.name LIKE '%clock%'
GROUP BY track.name
