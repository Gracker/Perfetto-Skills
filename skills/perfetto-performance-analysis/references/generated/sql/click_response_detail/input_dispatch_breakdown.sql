-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 9e44f27b6343d60763ebf83af07b3dd5c2d9c22a357c8f8527c54a3f67b5e497

SELECT
  'InputDispatcher' as stage,
  printf('%d', s.ts) as start_ts,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  t.name as thread_name,
  s.name as detail
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'system_server' OR p.name LIKE '/system/bin/%')
  AND (s.name GLOB '*InputDispatcher*' OR s.name GLOB '*InputReader*' OR s.name GLOB '*dispatchMotion*')
  AND s.ts >= (${event_ts} - 50000000)
  AND s.ts <= (${event_ts} + 50000000)
ORDER BY s.ts
LIMIT 20
