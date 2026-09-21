-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 337f07b019184e56d2cbd55423b8bdf1d62ee20eb90821ab2d0791340050512f
-- Source commit: bc007586871a720aed82537913617c64fb95a459

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
