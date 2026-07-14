-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 8fefc68721ff7d5c29a0efbcda086e11d9c62e892c17a37f39604b26b1729566
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH systemui AS (
  SELECT p.upid, p.pid
  FROM process p
  WHERE p.name LIKE '%systemui%'
    OR p.name LIKE '%SystemUI%'
    OR p.name = 'com.android.systemui'
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
JOIN systemui su ON t.upid = su.upid
WHERE t.tid = su.pid
  AND (s.name GLOB '*Choreographer#doFrame*'
       OR s.name GLOB '*doFrame*'
       OR s.name GLOB '*DrawFrame*')
