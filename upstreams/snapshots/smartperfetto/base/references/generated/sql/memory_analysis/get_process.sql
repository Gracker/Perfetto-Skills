-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 84ac77ef776250708d0bca27901eb5ceace572351055c4b6bf86dcd84986a1d0

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
