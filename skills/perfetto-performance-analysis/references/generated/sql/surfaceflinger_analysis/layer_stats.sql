-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 883c9e637f8166269939f7f817af9ef900c89e2215ca90cb3c0ad0d45443daad
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
