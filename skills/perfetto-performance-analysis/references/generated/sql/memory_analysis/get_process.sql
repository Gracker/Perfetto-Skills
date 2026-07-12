-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
