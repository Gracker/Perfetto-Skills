-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: a39931677061435b7e6004f603fa590fc51196fd1619697154b7f89e5c1510ec
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
