-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/scene_response_marker_facts.sql
-- Source SHA-256: 1d4b4b1e3d41541acb418fe44b3aaf53357b5fce9d1d02c852e1e99a7a9fa164
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
