-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/code_pinpoint.skill.yaml
-- Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT
  COALESCE(m.name, '(unknown)') AS module_name,
  COALESCE(m.build_id, '') AS build_id,
  COUNT(*) AS frame_count
FROM stack_profile_frame f
JOIN stack_profile_mapping m ON f.mapping = m.id
GROUP BY module_name, build_id
ORDER BY frame_count DESC
LIMIT 30;
