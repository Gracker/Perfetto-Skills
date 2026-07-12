-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts
),
clipped_contention AS (
  SELECT
    short_blocking_method,
    blocking_thread_name,
    short_blocked_method,
    blocked_thread_name,
    process_name,
    is_blocked_thread_main,
    waiter_count,
    MIN(CASE WHEN dur < 0 THEN aw.end_ts ELSE ts + dur END, aw.end_ts)
      - MAX(ts, aw.start_ts) AS clipped_ns
  FROM android_monitor_contention
  CROSS JOIN anr_window aw
  WHERE ts < aw.end_ts
    AND (CASE WHEN dur < 0 THEN aw.end_ts ELSE ts + dur END) > aw.start_ts
    AND ('${process_name}' = '' OR process_name = '${process_name}')
    AND is_blocked_thread_main = 1
    AND (
      MIN(CASE WHEN dur < 0 THEN aw.end_ts ELSE ts + dur END, aw.end_ts)
        - MAX(ts, aw.start_ts)
    ) >= 1000000  -- > 1ms inside the ANR window
)
SELECT
  short_blocking_method as blocking_method,
  blocking_thread_name,
  short_blocked_method as blocked_method,
  blocked_thread_name,
  process_name,
  CASE WHEN is_blocked_thread_main THEN 'MainThread' ELSE blocked_thread_name END as blocked_type,
  ROUND(clipped_ns / 1e6, 2) as wait_ms,
  waiter_count,
  -- 判断严重程度
  CASE
    WHEN clipped_ns / 1e6 > 1000 THEN 'critical'
    WHEN clipped_ns / 1e6 > 100 THEN 'warning'
    ELSE 'info'
  END as severity
FROM clipped_contention
ORDER BY clipped_ns DESC
LIMIT 10
