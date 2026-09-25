-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: e66c60cde78f1ab8ef436f3656397aa27cad975f9c7708d388926ad8eba3010a
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  s.name AS animation_type,
  COUNT(*) AS animation_count,
  CAST(AVG(s.dur) / 1e6 AS INTEGER) AS avg_dur_ms,
  CAST(MAX(s.dur) / 1e6 AS INTEGER) AS max_dur_ms,
  CAST(MIN(s.dur) / 1e6 AS INTEGER) AS min_dur_ms,
  CAST(SUM(s.dur) / 1e6 AS INTEGER) AS total_dur_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'system_server' OR p.name LIKE '%systemui%')
  AND (s.name GLOB '*WindowAnimation*'
       OR s.name GLOB '*Transition*'
       OR s.name GLOB '*openAnimation*'
       OR s.name GLOB '*closeAnimation*'
       OR s.name GLOB '*AppTransition*'
       OR s.name GLOB '*startingWindow*')
GROUP BY s.name
ORDER BY total_dur_ms DESC
LIMIT 20
