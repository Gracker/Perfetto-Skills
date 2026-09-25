-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdf7ef77bd46ca7ff4ab49a48acc199332397fade61d1e9cbc71b3270f4f8bc4
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
