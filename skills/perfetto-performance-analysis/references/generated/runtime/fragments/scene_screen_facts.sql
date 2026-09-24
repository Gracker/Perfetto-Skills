-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/scene_screen_facts.sql
-- Source SHA-256: e064d74cd1501151bf0dadebddabc3ac0ca8868f0ecf6677e10fa74e418bf866
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

-- SPDX-License-Identifier: AGPL-3.0-or-later
-- The pinned stdlib exposes TEXT, not Display.STATE_* numeric enum values.
-- On/off/AoD describe the display only, never keyguard or device Doze mode.
scene_screen_facts AS (
  SELECT id AS source_id, MAX(ts, (SELECT start_ts FROM trace_bounds)) AS ts,
    MIN(CASE WHEN dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts + dur END,
      (SELECT end_ts FROM trace_bounds)) AS end_ts,
    CASE simple_screen_state WHEN 'on' THEN 'SCREEN_ON' WHEN 'off' THEN 'SCREEN_OFF'
      WHEN 'doze' THEN 'SCREEN_DOZE' ELSE 'UNKNOWN' END AS state,
    screen_state AS raw_state, short_screen_state,
    CASE WHEN simple_screen_state IN ('on', 'off', 'doze') THEN 'observed' ELSE 'partial' END AS source_status,
    CASE WHEN dur = -1 THEN 'open' WHEN dur = 0 THEN 'instant' ELSE 'interval' END AS boundary_kind
  FROM android_screen_state WHERE (dur >= 0 OR dur = -1)
    AND ts <= (SELECT end_ts FROM trace_bounds)
    AND (dur = -1 OR ts + dur >= (SELECT start_ts FROM trace_bounds))
),
scene_screen_bounds AS (
  SELECT start_ts AS ts FROM trace_bounds UNION SELECT end_ts FROM trace_bounds
  UNION SELECT ts FROM scene_screen_facts UNION SELECT end_ts FROM scene_screen_facts
),
scene_screen_intervals AS (
  SELECT ts, LEAD(ts) OVER (ORDER BY ts) AS end_ts FROM scene_screen_bounds
),
scene_screen_lane AS (
  SELECT i.ts, i.end_ts,
    CASE WHEN COUNT(DISTINCT f.state) = 1 THEN MAX(f.state) ELSE 'UNKNOWN' END AS state,
    CASE WHEN COUNT(DISTINCT f.state) > 1 THEN 'conflict'
      WHEN COUNT(f.source_id) = 0 OR MAX(f.source_status = 'partial') THEN 'partial'
      ELSE 'observed' END AS source_status,
    MIN(f.source_id) || ',' || MAX(f.source_id) AS source_ids
  FROM scene_screen_intervals i LEFT JOIN scene_screen_facts f ON f.ts < i.end_ts AND f.end_ts > i.ts
  WHERE i.end_ts > i.ts GROUP BY i.ts, i.end_ts
)
