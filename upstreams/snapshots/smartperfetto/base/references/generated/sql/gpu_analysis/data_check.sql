-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: c99bd1159e7f337b0d5dd490100f66e9134271d55a7bbf0362ebf64d3a1d9602
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

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
