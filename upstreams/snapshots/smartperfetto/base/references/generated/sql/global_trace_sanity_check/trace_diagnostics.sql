-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: a38acbd87473cf64ef93cbdceadc701c047dbec3202ccb3af19a59f7ef9cf5ec
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
