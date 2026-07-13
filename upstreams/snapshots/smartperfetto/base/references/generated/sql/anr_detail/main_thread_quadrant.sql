-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH
main_thread AS (
  SELECT t.utid, t.tid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts,
    ${timeout_ns} as window_ns
),
thread_states AS (
  SELECT
    ts.state,
    COALESCE(ct.core_type, 'unknown') as core_type,
    ts.blocked_function,
    SUM(
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ) as dur_ns
  FROM thread_state ts
  JOIN main_thread mt ON ts.utid = mt.utid
  CROSS JOIN anr_window aw
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
  GROUP BY ts.state, ct.core_type, ts.blocked_function
),
quadrant_data AS (
  SELECT
    CASE
      WHEN state = 'Running' AND core_type IN ('prime', 'big') THEN 'Q1_big_running'
      WHEN state = 'Running' AND core_type IN ('medium', 'little') THEN 'Q2_little_running'
      WHEN state IN ('R', 'R+') THEN 'Q3_runnable'
      WHEN state IN ('S', 'D', 'I') THEN 'Q4_sleeping'
      ELSE 'other'
    END as quadrant,
    dur_ns,
    blocked_function
  FROM thread_states
)
SELECT
  ROUND(SUM(CASE WHEN quadrant = 'Q1_big_running' THEN dur_ns ELSE 0 END) / 1e6, 2) as q1_big_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q2_little_running' THEN dur_ns ELSE 0 END) / 1e6, 2) as q2_little_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ns ELSE 0 END) / 1e6, 2) as q3_runnable_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ns ELSE 0 END) / 1e6, 2) as q4_sleeping_ms,
  -- 总和与百分比
  ROUND(SUM(dur_ns) / 1e6, 2) as total_ms,
  ROUND(100.0 * SUM(CASE WHEN quadrant IN ('Q1_big_running', 'Q2_little_running') THEN dur_ns ELSE 0 END) /
        NULLIF(SUM(dur_ns), 0), 1) as running_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ns ELSE 0 END) /
        NULLIF(SUM(dur_ns), 0), 1) as runnable_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ns ELSE 0 END) /
        NULLIF(SUM(dur_ns), 0), 1) as sleeping_pct,
  -- 状态判断
  CASE
    WHEN 100.0 * SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ns ELSE 0 END) /
         NULLIF(SUM(dur_ns), 0) > 80 THEN 'blocked'
    WHEN 100.0 * SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ns ELSE 0 END) /
         NULLIF(SUM(dur_ns), 0) > 30 THEN 'cpu_starved'
    WHEN 100.0 * SUM(CASE WHEN quadrant IN ('Q1_big_running', 'Q2_little_running') THEN dur_ns ELSE 0 END) /
         NULLIF(SUM(dur_ns), 0) > 70 THEN 'busy_running'
    ELSE 'mixed'
  END as status_verdict
FROM quadrant_data
