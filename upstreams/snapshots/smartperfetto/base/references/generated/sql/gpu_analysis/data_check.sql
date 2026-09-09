-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 36f5184c4bd50b7001d0a1d14acaee52592734ad5771dec48bb5e811a7c66b96
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_gpu_frequency'
    ) THEN 1
    ELSE 0
  END as has_gpu_freq,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_gpu_memory_per_process'
    ) THEN 1
    ELSE 0
  END as has_gpu_memory,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'actual_frame_timeline_slice'
    ) THEN 1
    ELSE 0
  END as has_frame_timeline,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM android_gpu_frequency LIMIT 1
    ) THEN 1
    ELSE 0
  END as has_gpu_data
