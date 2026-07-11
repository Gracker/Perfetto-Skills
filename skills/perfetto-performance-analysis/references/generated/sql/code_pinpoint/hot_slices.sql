-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/code_pinpoint.skill.yaml
-- Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

INCLUDE PERFETTO MODULE slices.with_context;

SELECT
  process_name,
  thread_name,
  name AS slice_name,
  ROUND(dur / 1e6, 3) AS dur_ms
FROM thread_slice
WHERE dur > 0
  AND (${package} IS NULL OR process_name GLOB ${package} || '*')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts + dur <= ${end_ts})
ORDER BY dur DESC
LIMIT 30;
