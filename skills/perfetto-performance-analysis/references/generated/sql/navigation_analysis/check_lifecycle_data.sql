-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  COUNT(*) as event_count,
  CASE WHEN COUNT(*) > 0 THEN 'available' ELSE 'unavailable' END as status
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND (p.name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (
    s.name GLOB '*performCreate*'
    OR s.name GLOB '*performStart*'
    OR s.name GLOB '*performResume*'
    OR s.name GLOB '*performPause*'
    OR s.name GLOB '*performStop*'
    OR s.name GLOB '*performDestroy*'
    OR s.name GLOB '*activityStart*'
    OR s.name GLOB '*activityResume*'
  )
