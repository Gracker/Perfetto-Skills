-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  printf('%d', s.ts) as block_ts,
  printf('%d', s.dur) as dur_ns,
  s.name as blocking_op,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  CASE
    WHEN s.name GLOB '*inflate*' OR s.name GLOB '*LayoutInflater*' OR s.name GLOB '*setContentView*' THEN 'layout_inflate'
    WHEN s.name GLOB '*database*' OR s.name GLOB '*SQL*' OR s.name GLOB '*sqlite*' THEN 'database'
    WHEN s.name GLOB '*Binder*' OR s.name GLOB '*binder*' THEN 'binder'
    WHEN s.name GLOB '*file*' OR s.name GLOB '*IO*' OR s.name GLOB '*read*' OR s.name GLOB '*write*' THEN 'file_io'
    WHEN s.name GLOB '*GC*' OR s.name GLOB '*collector*' THEN 'gc'
    WHEN s.name GLOB '*network*' OR s.name GLOB '*http*' OR s.name GLOB '*okhttp*' THEN 'network'
    WHEN s.name GLOB '*SharedPreferences*' OR s.name GLOB '*getSharedPreferences*' THEN 'shared_prefs'
    ELSE 'other'
  END as block_type,
  CASE
    WHEN s.dur / 1e6 > 50 THEN 'critical'
    WHEN s.dur / 1e6 > ${binder_blocking_ms|16} THEN 'warning'
    WHEN s.dur / 1e6 > ${blocking_op_min_dur_ms|5} THEN 'notice'
    ELSE 'normal'
  END as severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND p.name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND s.dur > ${blocking_op_min_dur_ms|5} * 1000000
  AND s.name NOT GLOB '*performCreate*'
  AND s.name NOT GLOB '*performStart*'
  AND s.name NOT GLOB '*performResume*'
  AND s.name NOT GLOB '*performPause*'
  AND s.name NOT GLOB '*performStop*'
  AND s.name NOT GLOB '*performDestroy*'
  AND s.name NOT GLOB '*activityStart*'
  AND s.name NOT GLOB '*activityResume*'
ORDER BY s.dur DESC
LIMIT 30
