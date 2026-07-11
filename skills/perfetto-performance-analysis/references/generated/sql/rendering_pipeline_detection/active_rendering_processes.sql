-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

-- Fallback-first approach: Use DrawFrame slice counts
-- This works on all Android versions and is more reliable
-- actual_frame_timeline_slice is only available on Android 12+ with FrameTimeline enabled
SELECT
  p.upid,
  p.name as process_name,
  COUNT(*) as frame_count,
  MAX(t.tid) as render_thread_tid
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.name = 'RenderThread'
  AND s.name GLOB 'DrawFrame*'
  AND p.name IS NOT NULL
  AND p.name NOT LIKE 'com.android.systemui%'
  AND p.name NOT LIKE '/system/%'
  AND p.name NOT LIKE 'system_server%'
GROUP BY p.upid
HAVING frame_count > 5  -- Require at least 5 frames to be considered active
ORDER BY frame_count DESC
LIMIT 10
