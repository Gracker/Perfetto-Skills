-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_class_loading_in_range.skill.yaml
-- Source SHA-256: 664d113170724cd4624484f648f9f4570e1b77552d7e57bbb821ac28786465ea
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
WHERE (('${package}' = '' OR s.package = '${package}' OR s.package GLOB '${package}:*') OR '${package}' = '')
  AND (${startup_id} IS NULL OR s.startup_id = ${startup_id})
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
GROUP BY cl.slice_name
ORDER BY total_dur_ms DESC
LIMIT ${top_k|10}
