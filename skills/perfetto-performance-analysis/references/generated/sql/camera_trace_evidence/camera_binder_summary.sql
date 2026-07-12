-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: e04e0e2abc55ba999b714a2c10b4ef880e1770e26691a3ea05fa412cf78ec05b
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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
)
SELECT
  printf('%d', client_ts) AS ts,
  printf('%d', MAX(client_dur, 0)) AS dur_ns,
  COALESCE(aidl_name, interface, method_name, '<unknown interface>') AS aidl_name,
  COALESCE(client_process, '<unnamed process>') AS client_process,
  COALESCE(client_thread, '<unnamed thread>') AS client_thread,
  COALESCE(server_process, '<unnamed process>') AS server_process,
  COALESCE(server_thread, '<unnamed thread>') AS server_thread,
  client_upid,
  client_utid,
  server_upid,
  server_utid,
  'android_binder_txns' AS source,
  'Binder rows provide cross-process correlation; interface names and endpoints must still be verified.' AS limitation
FROM android_binder_txns, input
WHERE client_ts >= input.start_ts
  AND client_ts < input.end_ts
  AND (
    lower(COALESCE(client_process, '')) GLOB '*camera*'
    OR lower(COALESCE(server_process, '')) GLOB '*camera*'
    OR lower(COALESCE(client_process, '')) GLOB '*camx*'
    OR lower(COALESCE(server_process, '')) GLOB '*camx*'
    OR lower(COALESCE(client_process, '')) GLOB '*mtkcam*'
    OR lower(COALESCE(server_process, '')) GLOB '*mtkcam*'
  )
ORDER BY client_dur DESC, client_ts
LIMIT (SELECT max_rows FROM input)
