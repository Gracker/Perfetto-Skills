-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: 4c0d82a72e79c8ac5f42f5c57ff618e5bc0211d2d8f4c88c79642fbddd4ac263

WITH launcher AS (
  SELECT p.upid, p.pid
  FROM process p
  WHERE p.name LIKE '%launcher%'
    OR p.name LIKE '%Launcher%'
    OR p.name LIKE '%trebuchet%'
    OR p.name LIKE '%nexuslauncher%'
  LIMIT 1
)
SELECT
  COUNT(*) AS total_frames,
  SUM(CASE WHEN s.dur > 16670000 THEN 1 ELSE 0 END) AS jank_frames,
  ROUND(SUM(CASE WHEN s.dur > 16670000 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS jank_rate_pct,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_frame_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_frame_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN launcher l ON t.upid = l.upid
WHERE t.tid = l.pid
  AND (s.name GLOB '*Choreographer#doFrame*'
       OR s.name GLOB '*doFrame*'
       OR s.name GLOB '*DrawFrame*')
