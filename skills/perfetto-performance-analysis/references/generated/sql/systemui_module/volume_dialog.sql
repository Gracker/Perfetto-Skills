-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 8fefc68721ff7d5c29a0efbcda086e11d9c62e892c17a37f39604b26b1729566
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH systemui AS (
  SELECT p.upid
  FROM process p
  WHERE p.name LIKE '%systemui%'
    OR p.name LIKE '%SystemUI%'
    OR p.name = 'com.android.systemui'
  LIMIT 1
)
SELECT
  s.name AS volume_event,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN systemui su ON t.upid = su.upid
WHERE s.name GLOB '*Volume*'
  OR s.name GLOB '*volume*'
  OR s.name GLOB '*VolumeDialog*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 10
