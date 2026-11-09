-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: 3793610c048eb2cd2f719edc363d9f5cf72702f7b6b45fd0845449fba3423cd1

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
