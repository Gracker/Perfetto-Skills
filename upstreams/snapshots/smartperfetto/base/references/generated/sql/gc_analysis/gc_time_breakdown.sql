-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  process_name,
  gc_type,
  COUNT(*) AS gc_count,
  ROUND(SUM(gc_running_dur) / 1e6, 2) AS total_running_ms,
  ROUND(SUM(gc_runnable_dur) / 1e6, 2) AS total_runnable_ms,
  ROUND(SUM(gc_unint_io_dur) / 1e6, 2) AS total_io_wait_ms,
  ROUND(SUM(gc_unint_non_io_dur) / 1e6, 2) AS total_kernel_wait_ms,
  ROUND(SUM(gc_int_dur) / 1e6, 2) AS total_sleep_ms,
  ROUND(SUM(gc_dur) / 1e6, 2) AS total_wall_ms
FROM android_garbage_collection_events
WHERE CASE WHEN '${package}' != ''
           THEN process_name GLOB '*${package}*'
           ELSE 1 END
  AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
GROUP BY process_name, gc_type
ORDER BY total_wall_ms DESC
