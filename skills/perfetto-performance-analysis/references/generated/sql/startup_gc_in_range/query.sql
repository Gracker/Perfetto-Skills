-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_gc_in_range.skill.yaml
-- Source SHA-256: 5f4f1e48270ae77c92d5b68fd2ccd0cdd2299f386239316e3e0647f3aba1b8f7
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  ts.slice_name as gc_type,
  ts.thread_name,
  ts.is_main_thread,
  COUNT(*) as count,
  SUM(ts.slice_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(ts.slice_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(100.0 * SUM(ts.slice_dur) / s.dur, 1) as percent_of_startup
FROM android_thread_slices_for_all_startups ts
JOIN android_startups s ON ts.startup_id = s.startup_id
WHERE (s.package GLOB '${package}*' OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (ts.slice_name GLOB '*GC*' OR ts.slice_name GLOB '*gc*')
GROUP BY ts.slice_name, ts.is_main_thread
ORDER BY total_dur_ms DESC
LIMIT ${top_k|10}
