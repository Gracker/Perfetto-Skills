-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 7fe3eb2595b5f8920c8da24ca631b91a13f1e04ac0fe3dda1f3efae096b3319b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
           THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
           ELSE 1 END
  AND gc_dur / 1e6 >= COALESCE(${min_gc_dur_ms|5}, 5) * 2
  AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
ORDER BY gc_dur DESC
LIMIT 30
