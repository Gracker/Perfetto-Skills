-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 7ec44d892abb05141d0c58bfb05944911a22d8a6d4252fc95aa9b12c5f4f800a
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH available_metrics AS (
  SELECT
    (SELECT COUNT(*) FROM gpu_counter_track WHERE name GLOB '*freq*') as has_freq,
    (SELECT COUNT(*) FROM gpu_counter_track WHERE name GLOB '*util*') as has_util,
    (SELECT COUNT(*) FROM slice WHERE (name GLOB '*GPU*' AND name NOT GLOB '*DEADLINE*' AND name NOT GLOB '*MISSED*') OR name GLOB '*fence*') as has_slices
)
SELECT
  CASE WHEN has_freq > 0 THEN '可用' ELSE '不可用' END as freq_data,
  CASE WHEN has_util > 0 THEN '可用' ELSE '不可用' END as util_data,
  CASE WHEN has_slices > 0 THEN '可用' ELSE '不可用' END as slice_data,
  has_freq + has_util + has_slices as total_metrics
FROM available_metrics
