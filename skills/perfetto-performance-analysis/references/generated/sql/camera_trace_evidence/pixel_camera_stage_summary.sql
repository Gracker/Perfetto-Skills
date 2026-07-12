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
