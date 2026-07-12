-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 8fefc68721ff7d5c29a0efbcda086e11d9c62e892c17a37f39604b26b1729566
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH systemui AS (
  SELECT p.upid
  FROM process p
  WHERE p.name LIKE '%systemui%'
    OR p.name LIKE '%SystemUI%'
    OR p.name = 'com.android.systemui'
  LIMIT 1
)
SELECT
  s.name AS lock_event,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN systemui su ON t.upid = su.upid
WHERE s.name GLOB '*Keyguard*'
  OR s.name GLOB '*keyguard*'
  OR s.name GLOB '*LockScreen*'
  OR s.name GLOB '*lockscreen*'
  OR s.name GLOB '*Bouncer*'
  OR s.name GLOB '*unlock*'
  OR s.name GLOB '*Unlock*'
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15
