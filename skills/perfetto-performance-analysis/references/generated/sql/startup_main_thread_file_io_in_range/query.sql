-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_main_thread_file_io_in_range.skill.yaml
-- Source SHA-256: 436027333c6a01850793d5d5bb3e6d8d51be54fbd9812155923edf9367425f33
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  ts.slice_name as io_slice,
  ts.thread_name,
  COUNT(*) as count,
  SUM(ts.slice_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(ts.slice_dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(ts.slice_dur) / 1e6, 2) as max_dur_ms,
  '${startup_type}' as startup_type,
  ROUND(100.0 * SUM(ts.slice_dur) / s.dur, 1) as percent_of_startup
FROM android_thread_slices_for_all_startups ts
JOIN android_startups s ON ts.startup_id = s.startup_id
WHERE ts.is_main_thread = 1
  AND (s.package GLOB '${package}*' OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND ts.slice_dur > ${min_dur_ns|500000}
  AND (
    lower(ts.slice_name) GLOB '*open*'
    OR lower(ts.slice_name) GLOB '*read*'
    OR lower(ts.slice_name) GLOB '*write*'
    OR lower(ts.slice_name) GLOB '*fsync*'
    OR lower(ts.slice_name) GLOB '*fdatasync*'
    OR lower(ts.slice_name) GLOB '*sqlite*'
    OR lower(ts.slice_name) GLOB '*database*'
    OR lower(ts.slice_name) GLOB '*file*'
    OR lower(ts.slice_name) GLOB '*disk*'
  )
GROUP BY ts.slice_name, s.startup_id
ORDER BY total_dur_ms DESC
LIMIT ${top_k|15}
