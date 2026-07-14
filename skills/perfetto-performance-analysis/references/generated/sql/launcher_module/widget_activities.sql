-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: 09423f22ca1cc723d498d6e9ecfbfb935d5cf177154c5eab813f3bf7d0bcef40
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH launcher AS (
  SELECT p.upid
  FROM process p
  WHERE p.name LIKE '%launcher%'
    OR p.name LIKE '%Launcher%'
    OR p.name LIKE '%trebuchet%'
    OR p.name LIKE '%nexuslauncher%'
  LIMIT 1
)
SELECT
  s.name AS widget_activity,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN launcher l ON t.upid = l.upid
WHERE s.name GLOB '*widget*'
  OR s.name GLOB '*Widget*'
  OR s.name GLOB '*AppWidget*'
  OR s.name GLOB '*RemoteViews*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15
