-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/scene_input_window.sql
-- Source SHA-256: 7f089f40766b6d80c41e6cd9b39f9c1ff0ade7b2b771edf757e710e1260e5dd8
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Normalize the full input stream before clipping. Gesture/source identity and
-- pre-window DOWN or post-window UP remain in the original fact provenance.
scene_requested_bounds AS (
  SELECT MAX(start_ts, COALESCE(${start_ts}, start_ts)) AS start_ts,
    MIN(end_ts, COALESCE(${end_ts}, end_ts)) AS end_ts FROM trace_bounds
),
scene_windowed_gestures AS (
  SELECT g.*, MAX(g.ts, b.start_ts) AS clipped_ts, MIN(g.end_ts, b.end_ts) AS clipped_end_ts
  FROM scene_gestures g CROSS JOIN scene_requested_bounds b
  WHERE b.end_ts >= b.start_ts AND (
    (g.end_ts > g.ts AND g.ts < b.end_ts AND g.end_ts > b.start_ts) OR
    (g.end_ts = g.ts AND g.ts >= b.start_ts AND
      (g.ts < b.end_ts OR (b.end_ts = (SELECT end_ts FROM trace_bounds) AND g.ts = b.end_ts))))
)
