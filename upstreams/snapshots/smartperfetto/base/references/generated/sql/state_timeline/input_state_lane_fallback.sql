-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: 847df75d4dff0db6d9e8a10b5d5654d248cc898fde909ce265075dfb85209401
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
gesture_events AS (
  SELECT
    read_time AS ts,
    event_action,
    CASE WHEN event_action IN ('DOWN', 'POINTER_DOWN') THEN 1 ELSE 0 END AS is_start
  FROM android_input_events
  WHERE event_type = 'MOTION'
),
gesture_groups AS (
  SELECT ts, event_action,
    SUM(is_start) OVER (ORDER BY ts) AS gesture_id
  FROM gesture_events
),
gesture_summary AS (
  SELECT
    gesture_id,
    MIN(ts) AS start_ts,
    MAX(ts) AS end_ts,
    MAX(ts) - MIN(ts) AS dur,
    COUNT(*) AS event_count,
    COUNT(CASE WHEN event_action = 'MOVE' THEN 1 END) AS move_count,
    MAX(CASE WHEN event_action IN ('UP', 'POINTER_UP') THEN ts END) AS up_ts,
    MAX(CASE WHEN event_action = 'CANCEL' THEN 1 ELSE 0 END) AS was_cancelled
  FROM gesture_groups
  WHERE gesture_id > 0
  GROUP BY gesture_id
  HAVING event_count >= 2
),
classified AS (
  SELECT
    gesture_id,
    start_ts,
    COALESCE(up_ts, end_ts) AS end_ts,
    CASE
      WHEN was_cancelled = 1 THEN 'TAP'
      WHEN move_count >= 3 THEN 'SCROLL_DRAG'
      WHEN dur >= 300000000 AND move_count <= 2 THEN 'LONG_PRESS'
      ELSE 'TAP'
    END AS state,
    move_count,
    was_cancelled
  FROM gesture_summary
),
-- FLING: heuristic — from UP to next DOWN (max 3s)
fling_candidates AS (
  SELECT
    c.end_ts AS start_ts,
    MIN(
      COALESCE(
        (SELECT c2.start_ts FROM classified c2
         WHERE c2.start_ts > c.end_ts
         ORDER BY c2.start_ts LIMIT 1),
        c.end_ts + 3000000000
      ),
      c.end_ts + 3000000000
    ) AS end_ts,
    'FLING' AS state
  FROM classified c
  WHERE c.state = 'SCROLL_DRAG'
    AND c.move_count >= 4
    AND c.end_ts < (SELECT t_end FROM trace_bounds)
),
input_events AS (
  SELECT start_ts, end_ts, state FROM classified
  UNION ALL
  SELECT start_ts, end_ts, state FROM fling_candidates
  WHERE end_ts > start_ts + 16000000
),
ordered AS (
  SELECT start_ts, end_ts, state,
    ROW_NUMBER() OVER (ORDER BY start_ts) AS rn
  FROM input_events
  ORDER BY start_ts
),
idle_gaps AS (
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'IDLE' AS state
  WHERE NOT EXISTS (SELECT 1 FROM ordered)

  UNION ALL

  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    (SELECT MIN(start_ts) FROM ordered) AS end_ts,
    'IDLE' AS state
  WHERE EXISTS (SELECT 1 FROM ordered)
    AND (SELECT MIN(start_ts) FROM ordered) > (SELECT t_start FROM trace_bounds)

  UNION ALL

  SELECT
    o1.end_ts AS start_ts,
    o2.start_ts AS end_ts,
    'IDLE' AS state
  FROM ordered o1
  JOIN ordered o2 ON o2.rn = o1.rn + 1
  WHERE o2.start_ts > o1.end_ts

  UNION ALL

  SELECT
    (SELECT MAX(end_ts) FROM ordered) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'IDLE' AS state
  WHERE EXISTS (SELECT 1 FROM ordered)
    AND (SELECT MAX(end_ts) FROM ordered) < (SELECT t_end FROM trace_bounds)
),
all_raw AS (
  SELECT start_ts, end_ts, state FROM ordered
  UNION ALL
  SELECT start_ts, end_ts, state FROM idle_gaps
  WHERE end_ts > start_ts
)
SELECT
  'input' AS lane,
  state,
  CASE state
    WHEN 'IDLE' THEN '空闲'
    WHEN 'TAP' THEN '点击'
    WHEN 'LONG_PRESS' THEN '长按'
    WHEN 'SCROLL_DRAG' THEN '按压滑动'
    WHEN 'FLING' THEN '惯性滑动'
    ELSE state
  END AS state_label,
  printf('%d', start_ts) AS start_ts,
  printf('%d', end_ts) AS end_ts,
  end_ts - start_ts AS dur_ns,
  CAST((end_ts - start_ts) / 1000000 AS INT) AS dur_ms,
  'available_heuristic' AS source_status
FROM all_raw
WHERE end_ts > start_ts
ORDER BY start_ts
LIMIT 1000
