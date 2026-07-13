-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 8fefc68721ff7d5c29a0efbcda086e11d9c62e892c17a37f39604b26b1729566
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH systemui AS (
  SELECT p.upid
  FROM process p
  WHERE p.name LIKE '%systemui%'
    OR p.name LIKE '%SystemUI%'
    OR p.name = 'com.android.systemui'
  LIMIT 1
)
SELECT
  s.name AS nav_event,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN systemui su ON t.upid = su.upid
WHERE s.name GLOB '*Navigation*'
  OR s.name GLOB '*navigation*'
  OR s.name GLOB '*NavBar*'
  OR s.name GLOB '*navbar*'
  OR s.name GLOB '*gesture*'
  OR s.name GLOB '*Gesture*'
  OR s.name GLOB '*swipe*'
  OR s.name GLOB '*Swipe*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15
