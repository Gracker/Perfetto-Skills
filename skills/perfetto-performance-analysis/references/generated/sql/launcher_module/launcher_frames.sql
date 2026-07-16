-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: 09423f22ca1cc723d498d6e9ecfbfb935d5cf177154c5eab813f3bf7d0bcef40
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
