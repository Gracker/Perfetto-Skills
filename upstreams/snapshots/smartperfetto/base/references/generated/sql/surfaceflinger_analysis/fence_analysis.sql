-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 59c8f596d0111ef62440eb05318e85cfc2368d1d0b62d50ed6b1147b21e58aac
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  printf('%d', s.ts) as start_ts,
  s.dur,
  s.name as fence_type,
  CASE
    WHEN s.dur > ${fence_critical_ms|16} * 1000000 THEN 'critical'
    WHEN s.dur > ${fence_warning_ms|8} * 1000000 THEN 'warning'
    ELSE 'notice'
  END as severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
  AND (s.name GLOB '*fence*'
       OR s.name GLOB '*Fence*'
       OR s.name GLOB '*GPU completion*'
       OR s.name GLOB '*Waiting for GPU*')
  AND s.dur > 1000000  -- > 1ms
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
ORDER BY s.dur DESC
LIMIT 30
