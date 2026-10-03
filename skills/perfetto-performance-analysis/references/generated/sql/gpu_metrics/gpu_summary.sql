-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 80fe51882560c325dcd072ed62a0c07db6b43a2fdf215b072b366077ec1fbf51

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
