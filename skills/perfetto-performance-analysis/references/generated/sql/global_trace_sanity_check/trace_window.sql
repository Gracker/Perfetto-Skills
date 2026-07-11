-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 082c5e5e00286a42ebf2cb10e6d0305f0d94f83c2f64eb7baef061951d49dec8
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
