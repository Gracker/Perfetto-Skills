-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 9456c4556e1e976ba2c42d7261839a9deac5ebd010487a69b95b965f094a68b2
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
