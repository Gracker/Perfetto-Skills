-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/app/systemui_module.skill.yaml
-- Source SHA-256: 878a322c6ecb8d008c5c1eb3a818f63e55dfb38cdd5a00236fef47da90c6bd0a

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
