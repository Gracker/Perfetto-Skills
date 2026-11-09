-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/launcher_module.skill.yaml
-- Source SHA-256: a90057ce86d59a8bc077f03215ec72166ba59b83b7bdc56297cdec0a28e38622

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
