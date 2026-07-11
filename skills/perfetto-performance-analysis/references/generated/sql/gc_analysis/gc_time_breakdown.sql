-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 94563f8717669e993b92723f09bb10688c8a9ac9d9c9caf91391ddf4ecf14639
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
