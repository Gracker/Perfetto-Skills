-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 8fefc68721ff7d5c29a0efbcda086e11d9c62e892c17a37f39604b26b1729566
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH systemui AS (
  SELECT p.upid, p.pid
  FROM process p
  WHERE p.name LIKE '%systemui%'
    OR p.name LIKE '%SystemUI%'
    OR p.name = 'com.android.systemui'
  LIMIT 1
)
SELECT
  s.name AS binder_call,
  COUNT(*) AS count,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_ms,
  CAST(AVG(s.dur) / 1e6 AS REAL) AS avg_ms,
  CAST(MAX(s.dur) / 1e6 AS REAL) AS max_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN systemui su ON t.upid = su.upid
WHERE t.tid = su.pid  -- Main thread
  AND (s.name GLOB '*binder*'
       OR s.name GLOB '*Binder*'
       OR s.name GLOB '*aidl*'
       OR s.name GLOB '*AIDL*')
  AND s.dur > 1000000  -- > 1ms
GROUP BY s.name
ORDER BY total_ms DESC
LIMIT 15
