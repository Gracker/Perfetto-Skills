-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: b21af48bb190aa382256c422c77267cce8f041f42257cbbd3a6f669e691f5bf9
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND t.tid = p.pid
),
thread_states AS (
  SELECT
    ts.state,
    ts.cpu,
    ts.blocked_function,
    SUM(
      MIN(ts.ts + ts.dur, ${binder_end_ts}) - MAX(ts.ts, ${binder_ts})
    ) / 1e6 as dur_ms
  FROM thread_state ts
  JOIN main_thread mt ON ts.utid = mt.utid
  WHERE ts.ts < ${binder_end_ts}
    AND ts.ts + ts.dur > ${binder_ts}
  GROUP BY ts.state, ts.cpu, ts.blocked_function
),
quadrant_data AS (
  SELECT
    CASE
      WHEN state = 'Running' AND COALESCE((SELECT core_type FROM _cpu_topology WHERE cpu_id = thread_states.cpu), 'unknown') IN ('prime', 'big') THEN 'Q1_big_running'
      WHEN state = 'Running' THEN 'Q2_little_running'
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
  ROUND(SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ms ELSE 0 END), 2) as q3_runnable_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ms ELSE 0 END), 2) as q4_sleeping_ms,
  ROUND(SUM(dur_ms), 2) as total_ms,
  -- 百分比（Binder 期间主要是 Sleeping）
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as sleeping_pct
FROM quadrant_data
GROUP BY 1
