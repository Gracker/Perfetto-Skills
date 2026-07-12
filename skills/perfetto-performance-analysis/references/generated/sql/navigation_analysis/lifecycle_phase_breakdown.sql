-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  CASE
    WHEN s.name GLOB '*performCreate*' OR s.name GLOB '*activityStart*' THEN 'onCreate'
    WHEN s.name GLOB '*performStart*' THEN 'onStart'
    WHEN s.name GLOB '*performResume*' OR s.name GLOB '*activityResume*' THEN 'onResume'
    WHEN s.name GLOB '*performPause*' THEN 'onPause'
    WHEN s.name GLOB '*performStop*' THEN 'onStop'
    WHEN s.name GLOB '*performDestroy*' THEN 'onDestroy'
    ELSE 'other'
  END as phase,
  COUNT(*) as total_count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms,
  SUM(CASE WHEN s.dur / 1e6 > ${slow_lifecycle_ms|100} THEN 1 ELSE 0 END) as slow_count
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND p.name = '${target_process.data[0].process_name}'
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
GROUP BY phase
ORDER BY
  CASE phase
    WHEN 'onCreate' THEN 1
    WHEN 'onStart' THEN 2
    WHEN 'onResume' THEN 3
    WHEN 'onPause' THEN 4
    WHEN 'onStop' THEN 5
    WHEN 'onDestroy' THEN 6
    ELSE 7
  END
