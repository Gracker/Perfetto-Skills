-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: eec8bff767eb3277f1f0dd106d0d7a0cfdab2dfc

SELECT
  upid,
  pid,
  name as process_name
FROM process
WHERE name GLOB '${package}*' OR '${package}' = ''
ORDER BY
  CASE WHEN name GLOB '${package}*' THEN 0 ELSE 1 END,
  pid DESC
LIMIT 1
