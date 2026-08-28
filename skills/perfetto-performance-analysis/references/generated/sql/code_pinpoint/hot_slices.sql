-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/code_pinpoint.skill.yaml
-- Source SHA-256: 2a96d49f363c3a2c12b64d46cf466a3457020d6b5ade488a7ac8360a28e35bad
-- Source commit: 908d0897b0ae6b329d598f6d033a17543a62632a
-- Perfetto-Skills native overlay: deterministic trace-derived source anchors.

INCLUDE PERFETTO MODULE slices.with_context;

WITH scoped_slices AS (
  SELECT
    id AS slice_id,
    ts,
    dur AS dur_ns,
    ROUND(dur / 1e6, 3) AS dur_ms,
    upid,
    utid,
    process_name,
    thread_name,
    name AS slice_name,
    (
      '${package}' != ''
      AND is_main_thread = 1
      AND LENGTH(name) BETWEEN 2 AND 64
      AND SUBSTR(name, 1, 1) GLOB '[A-Z]'
      AND name NOT GLOB '*[^A-Za-z0-9]*'
      AND name GLOB '*[a-z]*'
    ) AS is_app_trace_label
  FROM thread_slice
  WHERE dur > 0
    AND (
      '${package}' = ''
      OR process_name = '${package}'
      OR (
        '${package}' != ''
        AND SUBSTR(process_name, 1, LENGTH('${package}') + 1) = '${package}' || ':'
      )
    )
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts + dur <= ${end_ts})
)
SELECT
  slice_id,
  ts,
  dur_ms,
  upid,
  utid,
  process_name,
  thread_name,
  slice_name,
  CASE
    WHEN is_app_trace_label THEN 'app_trace_label'
    ELSE 'generic_anchor_only'
  END AS anchor_kind,
  CASE
    WHEN is_app_trace_label THEN slice_name
    ELSE NULL
  END AS source_query_hint
FROM scoped_slices
ORDER BY dur_ns DESC, ts, slice_id
LIMIT 30;
