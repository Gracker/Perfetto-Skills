-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 1adb4b390eb80646b03d2994e975e118a1077859bf5dd960f70edeb33b0084e0
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH raw_input AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS raw_start_ts,
    COALESCE(${end_ts}, trace_end()) AS raw_end_ts,
    MIN(MAX(COALESCE(${max_rows|20}, 20), 1), 100) AS max_rows
),
input AS (
  SELECT
    MIN(raw_start_ts, raw_end_ts) AS start_ts,
    MAX(raw_start_ts, raw_end_ts) AS end_ts,
    max_rows
  FROM raw_input
)
SELECT
  printf('%d', start_ts) AS start_ts,
  printf('%d', end_ts) AS end_ts,
  ROUND((end_ts - start_ts) / 1e6, 2) AS duration_ms,
  max_rows
FROM input
