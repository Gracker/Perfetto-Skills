-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: d2f99680715212f30bafe86e1323d04cb469e5582ac89cad1e8c7b48f92e9c2e
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
raw_input AS (
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
),
candidates AS (
  SELECT
    'process' AS identity_kind,
    COALESCE(p.name, '<unnamed process>') AS process_name,
    CAST(NULL AS TEXT) AS thread_name,
    p.upid,
    p.pid,
    CAST(NULL AS INTEGER) AS utid,
    CAST(NULL AS INTEGER) AS tid,
    'process' AS source
  FROM process p
  WHERE lower(COALESCE(p.name, '')) GLOB '*camera*'
     OR lower(COALESCE(p.name, '')) GLOB '*camx*'
     OR lower(COALESCE(p.name, '')) GLOB '*mtkcam*'
  UNION ALL
  SELECT
    'thread',
    COALESCE(p.name, '<unnamed process>'),
    COALESCE(t.name, '<unnamed thread>'),
    t.upid,
    p.pid,
    t.utid,
    t.tid,
    'thread'
  FROM thread t
  LEFT JOIN process p ON p.upid = t.upid
  WHERE lower(COALESCE(t.name, '')) GLOB '*camera*'
     OR lower(COALESCE(t.name, '')) GLOB '*camx*'
     OR lower(COALESCE(t.name, '')) GLOB '*mtkcam*'
)
SELECT
  identity_kind,
  process_name,
  thread_name,
  upid,
  pid,
  utid,
  tid,
  source,
  'Name matches are identity candidates; verify process/thread ownership before attributing Camera work.' AS limitation
FROM candidates, input
ORDER BY identity_kind, process_name, thread_name
LIMIT (SELECT max_rows FROM input)
