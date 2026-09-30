-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: bfd2cd1f208acc814f9da8ed0ec0b02c0d5fd7226da25bec898e8de516e315cd

SELECT
  s.package AS package_name,
  s.startup_type AS launch_type,
  CAST(s.dur / 1e6 AS INTEGER) AS total_ms,
  CAST(ttd.time_to_initial_display / 1e6 AS INTEGER) AS ttid_ms,
  CAST(ttd.time_to_full_display / 1e6 AS INTEGER) AS ttfd_ms,
  s.ts AS start_ts
FROM android_startups s
LEFT JOIN android_startup_time_to_display ttd USING (startup_id)
WHERE ('${package}' = '' OR s.package = '${package}')
ORDER BY s.ts DESC
LIMIT 10
