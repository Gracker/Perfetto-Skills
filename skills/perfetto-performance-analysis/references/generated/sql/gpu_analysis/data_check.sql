-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 700737c3b798446d259b725cdb99906ea5b2a4b8b3a6334401f1cc18b352b061

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
