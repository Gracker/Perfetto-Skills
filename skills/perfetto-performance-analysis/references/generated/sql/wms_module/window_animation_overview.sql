-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/wms_module.skill.yaml
-- Source SHA-256: ec088f394851b6fb0426109a0105b0d0ae930adf759b15011ab45a18a1a5831f
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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
