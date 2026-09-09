-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_gc_in_range.skill.yaml
-- Source SHA-256: bd94ddc6c547e8a1b44089aaa9dd3e35dc89278858bb442eb18dcb417febf36a
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
WHERE (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (ts.slice_name GLOB '*GC*' OR ts.slice_name GLOB '*gc*')
GROUP BY ts.slice_name, ts.is_main_thread
ORDER BY total_dur_ms DESC
LIMIT ${top_k|10}
