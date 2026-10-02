-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 173f88b137c8d74b94c90839398d803aea4e0f655a143d76102fe519e2094f68

SELECT
  upid,
  pid,
  name as process_name
FROM process
WHERE ('${package}' = '' OR name = '${package}' OR name GLOB '${package}:*') OR '${package}' = ''
ORDER BY
  CASE WHEN ('${package}' = '' OR name = '${package}' OR name GLOB '${package}:*') THEN 0 ELSE 1 END,
  pid DESC
LIMIT 1
