-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/code_pinpoint.skill.yaml
-- Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  COALESCE(m.name, '(unknown)') AS module_name,
  COALESCE(m.build_id, '') AS build_id,
  COUNT(*) AS frame_count
FROM stack_profile_frame f
JOIN stack_profile_mapping m ON f.mapping = m.id
GROUP BY module_name, build_id
ORDER BY frame_count DESC
LIMIT 30;
