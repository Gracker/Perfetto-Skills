-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gc_events_in_range.skill.yaml
-- Source SHA-256: 1b3a5a7f2e13ed61dddef00d1d78f2fb1032e35ed9bcccb6559913ea8ca73d11
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

-- Use Perfetto stdlib android_garbage_collection_events (precise gc_type classification,
-- heap metrics, and CPU state breakdown). Note: returns 0 rows on older traces that
-- lack GC tracepoints; the agent should fall back to manual GLOB-based slice query.
SELECT
  gc_ts as ts,
  gc_dur as dur,
  gc_type as gc_name,
  thread_name,
  tid,
  pid,
  process_name,
  CASE WHEN tid = pid THEN 1 ELSE 0 END as is_main_thread,
  gc_type,
  -- Stdlib bonus columns (not available in fallback)
  is_mark_compact,
  reclaimed_mb,
  min_heap_mb,
  max_heap_mb,
  gc_running_dur,
  gc_runnable_dur,
  gc_unint_io_dur
FROM android_garbage_collection_events
WHERE process_name GLOB '${package}*'
  AND (${start_ts} IS NULL OR gc_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
ORDER BY gc_ts
