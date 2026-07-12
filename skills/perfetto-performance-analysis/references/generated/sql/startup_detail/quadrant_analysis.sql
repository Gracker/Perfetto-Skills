-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: 27c99e2bb5d9588e4ca6909bfd0a637f393af0211b692cc814005a00e99154c6
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

WITH main_thread AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid, p.name as process_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
    AND t.tid = p.pid
),
thread_states AS (
  SELECT
    ts.utid,
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    SUM(
      MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})
    ) / 1e6 as dur_ms
  FROM thread_state ts
  JOIN main_thread mt ON ts.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
  GROUP BY ts.utid, ts.state, ts.cpu
),
quadrant_data AS (
  SELECT
    CASE
      WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') THEN 'Q1_big_running'
      WHEN state = 'Running' AND core_type IN ('little') THEN 'Q2_little_running'
      WHEN state IN ('R', 'R+') THEN 'Q3_runnable'
      WHEN state IN ('D', 'DK') THEN 'Q4a_io_blocked'
      WHEN state IN ('S', 'I') THEN 'Q4b_sleeping'
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
  ROUND(SUM(CASE WHEN quadrant = 'Q4a_io_blocked' THEN dur_ms ELSE 0 END), 2) as q4a_io_blocked_ms,
  ROUND(SUM(CASE WHEN quadrant = 'Q4b_sleeping' THEN dur_ms ELSE 0 END), 2) as q4b_sleeping_ms,
  ROUND(SUM(dur_ms), 2) as total_ms,
  -- 百分比
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q1_big_running' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q1_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q2_little_running' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q2_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q3_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4a_io_blocked' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q4a_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4b_sleeping' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as q4b_pct,
  'topology_view' as classify_method
FROM quadrant_data
GROUP BY 1
