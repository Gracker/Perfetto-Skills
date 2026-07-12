-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  printf('%d', s.ts) as anim_ts,
  printf('%d', s.dur) as dur_ns,
  s.name as animation_event,
  ROUND(s.dur / 1e6, 2) as dur_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (
    s.name GLOB '*Transition*'
    OR s.name GLOB '*SharedElement*'
    OR s.name GLOB '*windowAnimation*'
    OR s.name GLOB '*ActivityTransition*'
  )
ORDER BY s.dur DESC
LIMIT 15
