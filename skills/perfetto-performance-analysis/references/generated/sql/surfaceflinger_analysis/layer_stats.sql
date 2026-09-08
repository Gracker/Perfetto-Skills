-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 59c8f596d0111ef62440eb05318e85cfc2368d1d0b62d50ed6b1147b21e58aac
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  s.name as layer_name,
  COUNT(*) as frame_count,
  SUM(s.dur) as total_dur,
  CAST(ROUND(AVG(s.dur)) AS INTEGER) as avg_dur
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
  AND s.name GLOB '*Layer*'
  AND s.dur > 0
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
GROUP BY s.name
ORDER BY total_dur DESC
LIMIT 20
