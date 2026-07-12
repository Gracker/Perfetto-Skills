-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: e3ba12b4a53d3c90d152f942c7f910e4108218ef5da2c56c0e19561009686fc2
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
-- Top app from battery stats (already has ts + duration)
app_segments AS (
  SELECT
    ts AS start_ts,
    ts + MAX(dur, 50000000) AS end_ts,
    str_value AS state,
    ROW_NUMBER() OVER (ORDER BY ts) AS rn
  FROM android_battery_stats_event_slices
  WHERE track_name = 'battery_stats.top'
    AND MAX(dur, 50000000) > 50000000
  ORDER BY ts
),
-- Gap filling (with empty-data fallback)
gaps AS (
  -- Fallback: no app data → single UNKNOWN covering entire trace
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'UNKNOWN' AS state
  WHERE NOT EXISTS (SELECT 1 FROM app_segments)

  UNION ALL

  -- Leading gap
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT MIN(start_ts) FROM app_segments) AS end_ts,
    'UNKNOWN' AS state
  WHERE EXISTS (SELECT 1 FROM app_segments)
    AND (SELECT MIN(start_ts) FROM app_segments) > (SELECT t_start FROM trace_bounds)

  UNION ALL

  -- Inter-app gaps (< 500ms → transitioning, >= 500ms → UNKNOWN)
  SELECT
    a1.end_ts AS start_ts,
    a2.start_ts AS end_ts,
    CASE
      WHEN a2.start_ts - a1.end_ts < 500000000 THEN '(transitioning)'
      ELSE 'UNKNOWN'
    END AS state
  FROM app_segments a1
  JOIN app_segments a2 ON a2.rn = a1.rn + 1
  WHERE a2.start_ts > a1.end_ts

  UNION ALL

  -- Trailing gap
  SELECT
    (SELECT MAX(end_ts) FROM app_segments) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'UNKNOWN' AS state
  WHERE EXISTS (SELECT 1 FROM app_segments)
    AND (SELECT MAX(end_ts) FROM app_segments) < (SELECT t_end FROM trace_bounds)
),
all_segments AS (
  SELECT start_ts, end_ts, state FROM app_segments
  UNION ALL
  SELECT start_ts, end_ts, state FROM gaps
)
SELECT
  'app' AS lane,
  state,
  CASE
    WHEN state = 'UNKNOWN' THEN '未知'
    WHEN state = '(transitioning)' THEN '切换中'
    ELSE REPLACE(REPLACE(state, 'com.', ''), 'android.', '')
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
