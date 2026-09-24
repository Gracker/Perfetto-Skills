-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: 2dc3194fd8730e6ce16c5d4db97860cc8cdfccee8b6b2f23dfd11ddb3d752ab4
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

WITH
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
SELECT printf('%d', ts) AS ts, printf('%d', end_ts - ts) AS dur,
  CASE state WHEN 'SCREEN_ON' THEN '屏幕点亮' WHEN 'SCREEN_OFF' THEN '屏幕熄灭'
    WHEN 'SCREEN_DOZE' THEN '屏幕低功耗显示（DOZE）' ELSE '屏幕状态未知' END AS event,
  'screen' AS category, state, raw_state, short_screen_state, source_status, boundary_kind,
  'android_screen_state' AS source_table, CAST(source_id AS TEXT) AS source_id,
  COUNT(*) OVER () AS total_rows
FROM scene_screen_facts WHERE end_ts >= ts ORDER BY ts
LIMIT MIN(MAX(CAST(${scene_row_limit|4096} AS INT), 1), 4096)
