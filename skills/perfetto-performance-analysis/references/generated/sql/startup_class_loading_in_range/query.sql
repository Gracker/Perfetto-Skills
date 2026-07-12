-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_class_loading_in_range.skill.yaml
-- Source SHA-256: 67a9f4747f25293a9194b9302ad554294fbc8efdd5397b50c7f74664a0899a34
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  cl.slice_name,
  cl.thread_name,
  COUNT(*) as count,
  SUM(cl.slice_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(cl.slice_dur) / 1e6, 2) as avg_dur_ms,
  '${startup_type}' as startup_type,
  ROUND(100.0 * SUM(cl.slice_dur) / s.dur, 1) as percent_of_startup
FROM android_class_loading_for_startup cl
JOIN android_startups s ON cl.startup_id = s.startup_id
WHERE (s.package GLOB '${package}*' OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
GROUP BY cl.slice_name
ORDER BY total_dur_ms DESC
LIMIT ${top_k|10}
