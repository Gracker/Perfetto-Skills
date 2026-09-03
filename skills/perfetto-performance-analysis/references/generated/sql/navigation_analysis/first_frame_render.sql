-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: b9e2d3fb86601d2c0f82d87e454f701201afac230ce76013877fe2252698fdb9
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  printf('%d', s.ts) as frame_ts,
  printf('%d', s.dur) as dur_ns,
  s.name as frame_event,
  ROUND(s.dur / 1e6, 2) as dur_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND p.name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND s.name GLOB '*Choreographer#doFrame*'
ORDER BY s.ts ASC
LIMIT 10
