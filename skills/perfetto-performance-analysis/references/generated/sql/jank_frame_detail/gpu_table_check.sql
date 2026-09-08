-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 89b4d18013a6f905876e70327ad35d2b6b486969311b984b2eabdcf58eeffa90
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM slice s
      JOIN thread_track tt ON s.track_id = tt.id
      JOIN thread t ON tt.utid = t.utid
      WHERE (t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster')
        AND (s.name GLOB '*Draw*' OR s.name GLOB '*eglSwap*' OR s.name GLOB '*Fence*')
      LIMIT 1
    ) THEN 1
    ELSE 0
  END as has_gpu_slices,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM sqlite_master
      WHERE type IN ('table', 'view') AND name = 'android_gpu_frequency'
    ) THEN 1
    ELSE 0
  END as has_gpu_freq
