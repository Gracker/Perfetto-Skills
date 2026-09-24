-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/scene_device_state_changes.skill.yaml
-- Source SHA-256: 095556b596031e7b8be9188eb7fef73927a190792460e88d97c190453848ed5f
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Shared exact scan/count and fact-output population; state semantics remain in the Skill.
bounds AS (
  SELECT MAX(start_ts, COALESCE(${start_ts}, start_ts)) AS start_ts,
    MIN(end_ts, COALESCE(${end_ts}, end_ts)) AS end_ts FROM trace_bounds
), committed_states AS (
  SELECT s.id, s.track_id, s.ts, s.name,
    LEAD(s.ts, 1, (SELECT end_ts FROM trace_bounds))
      OVER (PARTITION BY s.track_id ORDER BY s.ts, s.id) AS end_ts,
    LAG(s.name) OVER (PARTITION BY s.track_id ORDER BY s.ts, s.id) AS previous_value
  FROM slice s JOIN track t ON t.id = s.track_id
  WHERE t.name = 'DeviceStateChanged' AND s.dur = 0
), state_facts AS (
  SELECT 'screen' AS dimension, 'screen' AS object_key, ts AS start_ts, ts + dur AS end_ts,
    simple_screen_state AS state_value, short_screen_state AS raw_value,
    'android_screen_state' AS source_table, CAST(id AS TEXT) AS source_id,
    CASE WHEN simple_screen_state = 'unknown' THEN 'unknown' ELSE 'observed' END AS source_status,
    'stdlib_state_interval' AS boundary_basis, NULL AS previous_value,
    'screen_state_is_not_lock_state' AS semantic_limit, 'state_span' AS fact_kind, id AS source_order
  FROM android_screen_state WHERE dur > 0
  UNION ALL
  SELECT 'charging', 'charging', ts, ts + dur, short_charging_state, charging_state,
    'android_charging_states', CAST(id AS TEXT),
    CASE WHEN short_charging_state = 'unknown' THEN 'unknown' ELSE 'observed' END,
    'stdlib_state_interval', NULL, 'charging_is_not_cable_presence', 'state_span', id
  FROM android_charging_states WHERE dur > 0
  UNION ALL
  SELECT 'device_state', 'track:' || track_id, ts, end_ts, name, name, 'slice', CAST(id AS TEXT),
    CASE WHEN name IS NULL OR name = '' THEN 'unknown' ELSE 'observed' END,
    'committed_state_until_next_observation', previous_value,
    'posture_requires_device_state_configuration', 'state_span', id
  FROM committed_states WHERE end_ts > ts
  UNION ALL
  SELECT 'device_state', 'track:' || track_id, ts, ts, name, name, 'slice', CAST(id AS TEXT),
    CASE WHEN name IS NULL OR name = '' THEN 'unknown' ELSE 'observed' END,
    'observed_state_commit', previous_value, 'posture_requires_device_state_configuration', 'event', id
  FROM committed_states
), clipped AS (
  SELECT f.*, MAX(f.start_ts, b.start_ts) AS clipped_start,
    MIN(f.end_ts, b.end_ts) AS clipped_end
  FROM state_facts f CROSS JOIN bounds b
  WHERE b.end_ts >= b.start_ts AND (
    (f.fact_kind = 'state_span' AND b.end_ts > b.start_ts AND f.start_ts < b.end_ts AND f.end_ts > b.start_ts) OR
    (f.fact_kind = 'event' AND f.start_ts >= b.start_ts AND
      (f.start_ts < b.end_ts OR (b.end_ts = (SELECT end_ts FROM trace_bounds) AND f.start_ts = b.end_ts))))
)
SELECT d.dimension,
  (SELECT COUNT(*) FROM clipped c WHERE c.dimension = d.dimension) AS total_rows,
  (SELECT COUNT(*) FROM clipped c WHERE c.dimension = d.dimension AND source_status = 'observed') AS observed_rows,
  printf('%d', b.start_ts) AS start_ts, printf('%d', b.end_ts) AS end_ts,
  CASE WHEN (SELECT COUNT(*) FROM clipped) > MIN(4096, MAX(1, CAST(${row_limit|4096} AS INT))) THEN 1 ELSE 0 END AS output_truncated,
  1 AS cursor_closed, 0 AS parse_failure_count,
  CASE WHEN EXISTS (SELECT 1 FROM clipped c WHERE c.dimension = d.dimension AND source_status = 'observed')
    THEN 'partial' ELSE 'unavailable' END AS source_status,
  'source_presence_does_not_prove_capture_completeness' AS reason
FROM (SELECT 'screen' AS dimension UNION ALL SELECT 'charging' UNION ALL SELECT 'device_state') d CROSS JOIN bounds b
