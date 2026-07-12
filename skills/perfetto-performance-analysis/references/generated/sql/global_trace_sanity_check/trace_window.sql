-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 3c4b708b7b84c9206463877bf914275bb2d48df15eef7c821ebe6eeaf4a8e263
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

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
