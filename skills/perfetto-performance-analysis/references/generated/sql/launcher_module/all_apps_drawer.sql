-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: 09423f22ca1cc723d498d6e9ecfbfb935d5cf177154c5eab813f3bf7d0bcef40
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

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
  s.name AS drawer_event,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN launcher l ON t.upid = l.upid
WHERE s.name GLOB '*AllApps*'
  OR s.name GLOB '*allapps*'
  OR s.name GLOB '*drawer*'
  OR s.name GLOB '*Drawer*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 10
