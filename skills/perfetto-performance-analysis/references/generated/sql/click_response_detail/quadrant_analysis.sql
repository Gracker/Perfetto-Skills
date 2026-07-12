-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 3bf411e6c0f6db9de2434fb0ad420cb0a0140388c5968306f5ad569b3ff0c3e7
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND t.tid = p.pid
),
-- 检测拓扑分类来源
topology_meta AS (
  SELECT
    CASE
      WHEN MAX(ct.capacity) > 0 THEN 'capacity'
      WHEN EXISTS (SELECT 1 FROM cpu_counter_track WHERE name = 'cpufreq' LIMIT 1) THEN 'freq_rank'
      ELSE 'cpu_id_fallback'
    END as classify_method
  FROM _cpu_topology ct
),
thread_states AS (
  SELECT
    ts.state,
    COALESCE(ct.core_type, 'unknown') as core_type,
    ts.blocked_function,
    SUM(
      MIN(ts.ts + ts.dur, ${event_end_ts}) - MAX(ts.ts, ${event_ts})
    ) / 1e6 as dur_ms
  FROM thread_state ts
  JOIN main_thread mt ON ts.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${event_end_ts}
    AND ts.ts + ts.dur > ${event_ts}
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
  -- 百分比
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q3_runnable' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as runnable_pct,
  ROUND(100.0 * SUM(CASE WHEN quadrant = 'Q4_sleeping' THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as sleeping_pct,
  (SELECT classify_method FROM topology_meta) as classify_method
FROM quadrant_data
GROUP BY 1
