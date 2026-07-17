-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: d2f99680715212f30bafe86e1323d04cb469e5582ac89cad1e8c7b48f92e9c2e
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
  cam_id,
  COALESCE(node, '<unknown node>') AS node,
  COALESCE(port_group, '<unknown port group>') AS port_group,
  COUNT(*) AS frame_count,
  CAST(ROUND(AVG(dur)) AS INTEGER) AS avg_duration_ns,
  MAX(dur) AS max_duration_ns,
  'pixel_camera_frames' AS source,
  'pixel.camera is an optional Pixel slice parser; stage rows require vendor-specific interpretation and portable identity checks.' AS limitation
FROM pixel_camera_frames, input
WHERE ts >= input.start_ts
  AND ts < input.end_ts
GROUP BY cam_id, node, port_group
ORDER BY max_duration_ns DESC, frame_count DESC
LIMIT (SELECT max_rows FROM input)
