-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: eeadbc879f3b3e4118c66913d5a022ebec45f310e3ea34a03306d58cb80b9141

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    AND t.tid = p.pid
),
thread_states AS (
  SELECT
    ts.state,
    ts.cpu,
    ts.blocked_function,
    SUM(
      MIN(ts.ts + ts.dur, ${binder_end_ts}) - MAX(ts.ts, ${binder_ts})
    ) / 1e6 as dur_ms,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM thread_state ts
  JOIN main_thread mt ON ts.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${binder_end_ts}
    AND ts.ts + ts.dur > ${binder_ts}
  GROUP BY ts.state, ts.cpu, ts.blocked_function
),
quadrant_data AS (
  SELECT
    CASE
      WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') THEN 'Q1_big_running'
      WHEN state = 'Running' AND core_type = 'little' THEN 'Q2_little_running'
      WHEN state = 'Running' THEN 'unknown_running'
      WHEN state IN ('R', 'R+') THEN 'Q3_runnable'
      WHEN state IN ('S', 'D', 'I') THEN 'Q4_sleeping'
      ELSE 'other'
    END as quadrant,
    dur_ms
  FROM thread_states
)
SELECT
  'MainThread' as thread_type,
  ROUND(SUM(CASE WHEN quadrant = 'Q1_big_running' THEN dur_ms ELSE 0 END), 2) as q1_big_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q2_little_running' THEN dur_ms ELSE 0 END), 2) as q2_little_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'unknown_running' THEN dur_ms ELSE 0 END), 2) as unknown_running_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ms ELSE 0 END), 2) as q3_runnable_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ms ELSE 0 END), 2) as q4_sleeping_ms,
  ROUND(SUM(dur_ms), 2) as total_ms,
  -- 百分比（Binder 期间主要是 Sleeping）
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as sleeping_pct
FROM quadrant_data
GROUP BY 1
