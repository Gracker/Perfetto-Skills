-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/framework/ams_module.skill.yaml
-- Source SHA-256: bfd2cd1f208acc814f9da8ed0ec0b02c0d5fd7226da25bec898e8de516e315cd

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
