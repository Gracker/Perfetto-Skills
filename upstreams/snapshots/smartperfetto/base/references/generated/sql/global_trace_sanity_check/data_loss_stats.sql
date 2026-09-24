-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 1adb4b390eb80646b03d2994e975e118a1077859bf5dd960f70edeb33b0084e0
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 100) AS max_rows
)
SELECT name, idx, value, source, description
FROM stats
WHERE severity = 'data_loss' AND value > 0
ORDER BY value DESC, name, idx
LIMIT (SELECT max_rows FROM input)
