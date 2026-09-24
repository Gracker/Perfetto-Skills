-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 1adb4b390eb80646b03d2994e975e118a1077859bf5dd960f70edeb33b0084e0
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 100) AS max_rows
)
SELECT
  d.key,
  d.title,
  d.description,
  d.remediation,
  ROUND(d.confidence, 3) AS confidence,
  d.trace_id
FROM __intrinsic_trace_diagnostics d
ORDER BY d.confidence DESC, d.key, d.trace_id
LIMIT (SELECT max_rows FROM input)
