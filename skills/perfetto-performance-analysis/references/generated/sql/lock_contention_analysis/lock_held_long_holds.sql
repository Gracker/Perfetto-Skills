-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 2218440cfc32dab82a764464dea62719d04148dbaff34657cbe3590d4a063523
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

SELECT
  COALESCE(p.name, 'unknown') AS process_name,
  h.lock_name,
  COALESCE(t.name, 'tid:' || t.tid) AS holder_thread,
  t.tid AS holder_tid,
  COALESCE(t.is_main_thread, t.tid = p.pid, 0) AS is_main_thread,
  printf('%d', h.ts) AS ts,
  ROUND((
    MIN(h.ts + h.dur, COALESCE(${end_ts}, h.ts + h.dur))
      - MAX(h.ts, COALESCE(${start_ts}, h.ts))
  ) / 1e6, 2) AS held_ms,
  ROUND(h.dur / 1e6, 2) AS full_held_ms,
  h.blocking_method,
  h.is_incomplete,
  h.id AS slice_id
FROM android_lock_held AS h
JOIN thread AS t USING (utid)
LEFT JOIN process AS p USING (upid)
WHERE
  CASE WHEN '${process_name}' != ''
       THEN p.name GLOB '*${process_name}*'
       ELSE 1 END
  AND h.dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
  AND (${start_ts} IS NULL OR h.ts + h.dur > ${start_ts})
  AND (${end_ts} IS NULL OR h.ts < ${end_ts})
ORDER BY h.dur DESC
LIMIT 50
