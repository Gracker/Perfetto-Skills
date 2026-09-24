-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 1adb4b390eb80646b03d2994e975e118a1077859bf5dd960f70edeb33b0084e0
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 100) AS max_rows
)
SELECT name, idx, value, source, description
FROM stats
WHERE severity = 'data_loss' AND value > 0
ORDER BY value DESC, name, idx
LIMIT (SELECT max_rows FROM input)
