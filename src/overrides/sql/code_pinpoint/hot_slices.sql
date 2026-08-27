-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/code_pinpoint.skill.yaml
-- Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
-- Source commit: 908d0897b0ae6b329d598f6d033a17543a62632a
-- Perfetto-Skills native overlay: deterministic trace-derived source anchors.

INCLUDE PERFETTO MODULE slices.with_context;

SELECT
  id AS slice_id,
  ts,
  ROUND(dur / 1e6, 3) AS dur_ms,
  upid,
  utid,
  process_name,
  thread_name,
  name AS slice_name,
  CASE
    WHEN name = 'ChaosTask' THEN 'app_trace_label'
    WHEN name GLOB 'L*;*'
      OR name GLOB '*::*'
      OR name GLOB '*#*'
      THEN 'trace_symbol'
    ELSE 'generic_anchor_only'
  END AS anchor_kind,
  CASE
    WHEN name = 'ChaosTask'
      OR name GLOB 'L*;*'
      OR name GLOB '*::*'
      OR name GLOB '*#*'
      THEN name
    ELSE NULL
  END AS source_query_hint
FROM thread_slice
WHERE dur > 0
  AND (
    '${package}' = ''
    OR process_name = '${package}'
    OR process_name GLOB '${package}:*'
  )
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts + dur <= ${end_ts})
ORDER BY dur DESC, ts, id
LIMIT 30;
