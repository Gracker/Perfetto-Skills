-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/device_state_snapshot.skill.yaml
-- Source SHA-256: 886bf69ae41b697f5c80cad4e1787cc5198233e15f65cb3c9cb3d382ca3b3655
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH trace_bounds AS (
  SELECT
    COALESCE(${start_ts}, (SELECT MIN(ts) FROM slice)) as t_start,
    COALESCE(${end_ts}, (SELECT MAX(ts + dur) FROM slice)) as t_end
),
screen_state AS (
  SELECT
    'screen_state' as metric,
    CASE WHEN c.value > 0 THEN 'ON' ELSE 'OFF' END as value,
    c.ts as ts
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  CROSS JOIN trace_bounds tb
  WHERE (ct.name GLOB '*ScreenState*' OR ct.name GLOB '*screen_state*')
    AND c.ts >= tb.t_start AND c.ts <= tb.t_end
  ORDER BY c.ts DESC
  LIMIT 1
),
battery_info AS (
  SELECT
    'battery_level' as metric,
    CAST(c.value AS TEXT) as value,
    c.ts as ts
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  CROSS JOIN trace_bounds tb
  WHERE (ct.name GLOB '*battery_level*' OR ct.name GLOB '*BatteryLevel*')
    AND c.ts >= tb.t_start AND c.ts <= tb.t_end
  ORDER BY c.ts DESC
  LIMIT 1
),
charging_info AS (
  SELECT
    'charging_state' as metric,
    CASE WHEN c.value > 0 THEN 'CHARGING' ELSE 'NOT_CHARGING' END as value,
    c.ts as ts
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  CROSS JOIN trace_bounds tb
  WHERE (ct.name GLOB '*battery_status*' OR ct.name GLOB '*charging*' OR ct.name GLOB '*BatteryStatus*')
    AND c.ts >= tb.t_start AND c.ts <= tb.t_end
  ORDER BY c.ts DESC
  LIMIT 1
),
thermal_info AS (
  SELECT
    'thermal_zone' as metric,
    ct.name || ': ' || CAST(ROUND(MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END), 1) AS TEXT) || ' C' as value,
    MAX(c.ts) as ts
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  CROSS JOIN trace_bounds tb
  WHERE (ct.name GLOB '*thermal_zone*' OR ct.name GLOB '*Temperature*' OR ct.name GLOB '*temp*')
    AND c.ts >= tb.t_start AND c.ts <= tb.t_end
  GROUP BY ct.name
  ORDER BY MAX(c.value) DESC
  LIMIT 5
),
memory_info AS (
  SELECT
    'memory_pressure' as metric,
    ct.name || ': ' || CAST(ROUND(MAX(c.value), 0) AS TEXT) as value,
    MAX(c.ts) as ts
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  CROSS JOIN trace_bounds tb
  WHERE (ct.name GLOB '*mem.*pressure*' OR ct.name GLOB '*MemFree*' OR ct.name GLOB '*MemAvailable*' OR ct.name GLOB '*psi*mem*')
    AND c.ts >= tb.t_start AND c.ts <= tb.t_end
  GROUP BY ct.name
  ORDER BY MAX(c.value) DESC
  LIMIT 5
)
SELECT metric, value, printf('%d', ts) as ts FROM screen_state
UNION ALL SELECT metric, value, printf('%d', ts) as ts FROM battery_info
UNION ALL SELECT metric, value, printf('%d', ts) as ts FROM charging_info
UNION ALL SELECT metric, value, printf('%d', ts) as ts FROM thermal_info
UNION ALL SELECT metric, value, printf('%d', ts) as ts FROM memory_info
