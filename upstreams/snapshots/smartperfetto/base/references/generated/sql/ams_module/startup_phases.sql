-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: b7456b08a71144dfea211e1e651da605e3683fe7e4512fb761c7ae45b55d2074
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  name AS slice_name,
  CAST(dur / 1e6 AS REAL) AS dur_ms,
  ts
FROM slice
WHERE name LIKE '%bindApplication%'
  OR name LIKE '%activityStart%'
  OR name LIKE '%activityResume%'
  OR name LIKE '%Choreographer%doFrame%'
ORDER BY ts
LIMIT 50
