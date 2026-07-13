-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  printf('%d', gc_ts) AS gc_ts_nav,
  process_name,
  thread_name,
  gc_type,
  ROUND(gc_dur / 1e6, 2) AS gc_dur_ms,
  ROUND(gc_running_dur / 1e6, 2) AS running_ms,
  ROUND(gc_runnable_dur / 1e6, 2) AS runnable_ms,
  ROUND(reclaimed_mb, 2) AS reclaimed_mb,
  ROUND(max_heap_mb, 2) AS max_heap_mb,
  ROUND(min_heap_mb, 2) AS min_heap_mb
FROM android_garbage_collection_events
WHERE CASE WHEN '${package}' != ''
           THEN process_name GLOB '*${package}*'
           ELSE 1 END
  AND gc_dur / 1e6 >= COALESCE(${min_gc_dur_ms|5}, 5) * 2
  AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
ORDER BY gc_dur DESC
LIMIT 30
