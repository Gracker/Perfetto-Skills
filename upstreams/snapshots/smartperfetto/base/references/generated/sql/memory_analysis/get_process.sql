-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 51ddff1e843e8e91fa5b9e8f494b2c95beaf700729248e96efd733cbaea21e10

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
