-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_app_background_power_state.skill.yaml
-- Source SHA-256: 4ce3166f6ef8db3eca68f7a14cb6d6164abb3f15de2db690e545acc15ef4ff86
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS window_start,
    COALESCE(${end_ts}, trace_end()) AS window_end
),
wakelocks AS (
  -- Older runtimes: the BatteryStats longwake events android.app_wakelocks
  -- itself falls back to.
  SELECT ts, safe_dur AS dur, str_value AS name, int_value AS uid, 'battery_stats_longwake' AS source
  FROM android_battery_stats_event_slices
  WHERE track_name = 'battery_stats.longwake'
),
uid_names AS (
  SELECT uid % 100000 AS app_id, package_name AS name FROM package_list
  UNION
  SELECT uid % 100000 AS app_id, name FROM process WHERE uid IS NOT NULL AND name IS NOT NULL
),
clipped AS (
  SELECT
    w.uid,
    w.name AS tag,
    w.source,
    MIN(w.ts + w.dur, b.window_end) - MAX(w.ts, b.window_start) AS held_dur
  FROM wakelocks AS w
  CROSS JOIN bounds AS b
  WHERE w.ts < b.window_end AND w.ts + w.dur > b.window_start
    AND (
      '${package}' = ''
      OR w.uid % 100000 IN (
        SELECT app_id FROM uid_names
        WHERE name = '${package}' OR name GLOB '${package}:*'
      )
    )
)
SELECT
  c.uid,
  c.uid / 100000 AS user_id,
  (SELECT GROUP_CONCAT(DISTINCT n.name) FROM uid_names AS n WHERE n.app_id = c.uid % 100000) AS packages,
  c.tag,
  COUNT(*) AS wakelock_count,
  ROUND(SUM(c.held_dur) / 1e6, 2) AS total_held_ms,
  ROUND(MAX(c.held_dur) / 1e6, 2) AS max_held_ms,
  c.source
FROM clipped AS c
GROUP BY c.uid, c.tag, c.source
ORDER BY SUM(c.held_dur) DESC
LIMIT 50
