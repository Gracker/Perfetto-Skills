-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: b7456b08a71144dfea211e1e651da605e3683fe7e4512fb761c7ae45b55d2074
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
