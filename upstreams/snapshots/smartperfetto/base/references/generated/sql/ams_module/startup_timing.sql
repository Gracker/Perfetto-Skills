-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: a39931677061435b7e6004f603fa590fc51196fd1619697154b7f89e5c1510ec
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  s.package AS package_name,
  s.startup_type AS launch_type,
  CAST(s.dur / 1e6 AS INTEGER) AS total_ms,
  CAST(ttd.time_to_initial_display / 1e6 AS INTEGER) AS ttid_ms,
  CAST(ttd.time_to_full_display / 1e6 AS INTEGER) AS ttfd_ms,
  s.ts AS start_ts
FROM android_startups s
LEFT JOIN android_startup_time_to_display ttd USING (startup_id)
WHERE s.package LIKE '%${package}%'
ORDER BY s.ts DESC
LIMIT 10
