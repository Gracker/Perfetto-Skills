-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: a38acbd87473cf64ef93cbdceadc701c047dbec3202ccb3af19a59f7ef9cf5ec
-- Source commit: 908d0897b0ae6b329d598f6d033a17543a62632a

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
