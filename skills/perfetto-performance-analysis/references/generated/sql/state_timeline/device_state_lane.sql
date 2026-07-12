-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: e3ba12b4a53d3c90d152f942c7f910e4108218ef5da2c56c0e19561009686fc2
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
screen_segments AS (
  SELECT
    ts AS start_ts,
    ts + dur AS end_ts,
    CASE screen_state
      WHEN 1 THEN 'SCREEN_OFF'
      WHEN 2 THEN 'SCREEN_ON'
      WHEN 3 THEN 'SCREEN_DOZE'
      ELSE 'SCREEN_UNKNOWN'
    END AS state
  FROM android_screen_state
  WHERE dur > 0
  ORDER BY ts
),
numbered AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY start_ts) AS rn
  FROM screen_segments
),
-- Gap filling: leading, inter-segment, trailing
-- Uses COALESCE to handle empty screen_segments (table exists but no data)
gaps AS (
  -- Fallback: no screen data at all → single UNKNOWN covering entire trace
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'UNKNOWN' AS state
  WHERE NOT EXISTS (SELECT 1 FROM screen_segments)

  UNION ALL

  -- Leading gap: trace start → first screen event
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT MIN(start_ts) FROM screen_segments) AS end_ts,
    'UNKNOWN' AS state
  WHERE EXISTS (SELECT 1 FROM screen_segments)
    AND (SELECT MIN(start_ts) FROM screen_segments) > (SELECT t_start FROM trace_bounds)

  UNION ALL

  -- Inter-segment gaps (should be rare for screen_state)
  SELECT
    n1.end_ts AS start_ts,
    n2.start_ts AS end_ts,
    'UNKNOWN' AS state
  FROM numbered n1
  JOIN numbered n2 ON n2.rn = n1.rn + 1
  WHERE n2.start_ts > n1.end_ts

  UNION ALL

  -- Trailing gap: last screen event → trace end
  SELECT
    (SELECT MAX(end_ts) FROM screen_segments) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'UNKNOWN' AS state
  WHERE EXISTS (SELECT 1 FROM screen_segments)
    AND (SELECT MAX(end_ts) FROM screen_segments) < (SELECT t_end FROM trace_bounds)
),
all_segments AS (
  SELECT start_ts, end_ts, state FROM screen_segments
  UNION ALL
  SELECT start_ts, end_ts, state FROM gaps
)
SELECT
  'device' AS lane,
  state,
  CASE state
    WHEN 'SCREEN_ON' THEN '屏幕点亮'
    WHEN 'SCREEN_OFF' THEN '屏幕熄灭'
    WHEN 'SCREEN_DOZE' THEN '屏幕休眠'
    ELSE '未知'
  END AS state_label,
  printf('%d', start_ts) AS start_ts,
  printf('%d', end_ts) AS end_ts,
  end_ts - start_ts AS dur_ns,
  CAST((end_ts - start_ts) / 1000000 AS INT) AS dur_ms,
  'available' AS source_status
FROM all_segments
WHERE end_ts > start_ts
ORDER BY start_ts
LIMIT 200
