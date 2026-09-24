-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/scene_response_markers.skill.yaml
-- Source SHA-256: ffba8ce063278ad7adf1117f3147088dbb88f6d85aff3296d7cba291e26b6d50
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- This inventory observes named producer slices, not an entire scroll/fling.
-- Parameters embedded in a marker name have no established units or duration authority.
response_bounds AS (
  SELECT MAX(start_ts, COALESCE(${start_ts}, start_ts)) AS start_ts,
    MIN(end_ts, COALESCE(${end_ts}, end_ts)) AS end_ts FROM trace_bounds
), response_raw AS (
  SELECT s.id AS slice_id, s.ts, s.dur, s.name AS raw_name, s.track_id,
    tr.name AS track_name, tr.type AS track_type, tt.utid,
    th.name AS thread_name, th.upid AS thread_upid, pt.upid AS process_track_upid,
    CASE WHEN th.upid IS NOT NULL AND pt.upid IS NOT NULL AND th.upid != pt.upid THEN NULL
      ELSE COALESCE(th.upid, pt.upid) END AS upid,
    CASE WHEN th.upid IS NOT NULL AND pt.upid IS NOT NULL AND th.upid != pt.upid THEN 'conflict'
      WHEN th.upid IS NOT NULL THEN 'thread_track' WHEN pt.upid IS NOT NULL THEN 'process_track'
      ELSE 'unresolved' END AS identity_basis,
    CASE WHEN s.name = 'Scroll' THEN 'scroll_marker' ELSE 'fling_start_marker' END AS marker_kind,
    CASE WHEN s.ts >= 0 AND s.dur >= 0 AND s.dur <= 9223372036854775807 - s.ts THEN s.ts + s.dur END AS end_ts
  FROM slice s
  LEFT JOIN track tr ON tr.id = s.track_id
  LEFT JOIN thread_track tt ON tt.id = s.track_id
  LEFT JOIN thread th ON th.utid = tt.utid
  LEFT JOIN process_track pt ON pt.id = s.track_id
  WHERE s.name = 'Scroll' OR s.name = 'FlingStart' OR s.name GLOB 'FlingStart *'
), response_windowed AS (
  SELECT r.*, p.name AS process_name,
    MAX(r.ts, b.start_ts) AS scan_start_ts,
    CASE WHEN r.end_ts IS NOT NULL THEN MIN(r.end_ts, b.end_ts) END AS scan_end_ts
  FROM response_raw r CROSS JOIN response_bounds b
  LEFT JOIN process p ON p.upid = r.upid
  WHERE b.end_ts >= b.start_ts AND (
    (b.end_ts > b.start_ts AND r.end_ts > r.ts AND r.ts < b.end_ts AND r.end_ts > b.start_ts) OR
    ((r.end_ts = r.ts OR r.end_ts IS NULL) AND r.ts >= b.start_ts AND
      (r.ts < b.end_ts OR (b.end_ts = (SELECT end_ts FROM trace_bounds) AND r.ts = b.end_ts))))
)
SELECT printf('%d', b.start_ts) AS start_ts, printf('%d', b.end_ts) AS end_ts,
  (SELECT COUNT(*) FROM response_windowed) AS total_rows,
  CASE WHEN (SELECT COUNT(*) FROM response_windowed) > MIN(4096, MAX(1, CAST(${row_limit|4096} AS INT)))
    THEN 1 ELSE 0 END AS output_truncated,
  1 AS cursor_closed,
  (SELECT COUNT(*) FROM response_windowed WHERE dur < -1 OR (dur >= 0 AND end_ts IS NULL)) AS parse_failure_count,
  (SELECT COUNT(*) FROM response_windowed WHERE dur = -1) AS open_marker_count,
  CASE WHEN EXISTS (SELECT 1 FROM response_windowed) THEN 'partial' ELSE 'unavailable' END AS source_status,
  'unknown' AS capture_status,
  'exact_Scroll_or_FlingStart_name_or_FlingStart_space_prefix' AS marker_population,
  'query_population_only_not_all_application_responses' AS coverage_limit
FROM response_bounds b
