-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: e04e0e2abc55ba999b714a2c10b4ef880e1770e26691a3ea05fa412cf78ec05b
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
  COALESCE(process_name, '<unnamed process>') AS process_name,
  upid,
  pid,
  SUM(CASE WHEN buf_size > 0 THEN 1 ELSE 0 END) AS allocation_count,
  SUM(CASE WHEN buf_size > 0 THEN buf_size ELSE 0 END) AS allocation_bytes,
  -SUM(CASE WHEN buf_size < 0 THEN buf_size ELSE 0 END) AS release_bytes,
  SUM(buf_size) AS observed_net_delta_bytes,
  MAX(ABS(buf_size)) AS peak_event_bytes,
  'android_dmabuf_allocs' AS source,
  'Observed net delta covers only events inside this window; allocations may predate it and releases may occur later, so it is not retained memory or leak proof.' AS limitation
FROM android_dmabuf_allocs, input
WHERE ts >= input.start_ts
  AND ts < input.end_ts
  AND (
    lower(COALESCE(process_name, '')) GLOB '*camera*'
    OR lower(COALESCE(process_name, '')) GLOB '*camx*'
    OR lower(COALESCE(process_name, '')) GLOB '*mtkcam*'
    OR lower(COALESCE(thread_name, '')) GLOB '*camera*'
    OR lower(COALESCE(thread_name, '')) GLOB '*camx*'
    OR lower(COALESCE(thread_name, '')) GLOB '*mtkcam*'
  )
GROUP BY process_name, upid, pid
ORDER BY ABS(SUM(buf_size)) DESC, allocation_bytes DESC
LIMIT (SELECT max_rows FROM input)
