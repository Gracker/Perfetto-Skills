-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 0403339f9ba204e964aa7ccab7130157ed7149b13da3cfd63bb807484e4bbb96
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
