-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/selection_range_cpu_sched_summary.skill.yaml
-- Source SHA-256: 31127ebb648421f06248c4ceb054d614d12df318c63b0a652a41f341b556310e
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH
target_threads AS (
  SELECT
    t.utid,
    t.tid,
    COALESCE(t.name, '<unknown>') AS thread_name,
    p.upid,
    p.pid,
    COALESCE(p.name, '<unknown>') AS process_name
  FROM thread t
  LEFT JOIN process p ON t.upid = p.upid
  WHERE ('${package|}' = '' OR COALESCE(p.name, '') GLOB '${package|}*')
    AND ('${thread_name|}' = '' OR COALESCE(t.name, '') GLOB '*${thread_name|}*')
),
states AS (
  SELECT
    tt.utid,
    tt.tid,
    tt.thread_name,
    tt.process_name,
    ts.ts,
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') AS core_type,
    MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts}) AS clipped_dur
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
    AND ts.dur > 0
),
running_events AS (
  SELECT
    utid,
    ts,
    cpu,
    core_type,
    LAG(cpu) OVER (PARTITION BY utid ORDER BY ts) AS prev_cpu,
    LAG(core_type) OVER (PARTITION BY utid ORDER BY ts) AS prev_core_type
  FROM states
  WHERE state = 'Running' AND clipped_dur > 0
),
migrations AS (
  SELECT
    utid,
    SUM(CASE WHEN prev_cpu IS NOT NULL AND cpu != prev_cpu THEN 1 ELSE 0 END) AS migrations,
    SUM(CASE WHEN prev_cpu IS NOT NULL AND cpu != prev_cpu AND core_type != prev_core_type THEN 1 ELSE 0 END) AS cross_cluster_migrations
  FROM running_events
  GROUP BY utid
)
SELECT
  s.thread_name,
  s.process_name,
  s.tid,
  ROUND(SUM(CASE WHEN s.state = 'Running' THEN s.clipped_dur ELSE 0 END) / 1e6, 2) AS total_cpu_ms,
  ROUND(SUM(CASE WHEN s.state = 'Running' AND s.core_type IN ('prime', 'big', 'medium') THEN s.clipped_dur ELSE 0 END) / 1e6, 2) AS q1_perf_running_ms,
  ROUND(SUM(CASE WHEN s.state = 'Running' AND s.core_type = 'little' THEN s.clipped_dur ELSE 0 END) / 1e6, 2) AS q2_little_running_ms,
  ROUND(SUM(CASE WHEN s.state IN ('R', 'R+') THEN s.clipped_dur ELSE 0 END) / 1e6, 2) AS q3_runnable_ms,
  ROUND(SUM(CASE WHEN s.state IN ('D', 'DK') THEN s.clipped_dur ELSE 0 END) / 1e6, 2) AS q4a_io_blocked_ms,
  ROUND(SUM(CASE WHEN s.state IN ('S', 'I') THEN s.clipped_dur ELSE 0 END) / 1e6, 2) AS q4b_sleeping_ms,
  ROUND(100.0 * SUM(CASE WHEN s.state = 'Running' AND s.core_type IN ('prime', 'big', 'medium') THEN s.clipped_dur ELSE 0 END)
    / NULLIF(SUM(CASE WHEN s.state = 'Running' THEN s.clipped_dur ELSE 0 END), 0), 1) AS perf_core_pct,
  GROUP_CONCAT(DISTINCT CASE WHEN s.state = 'Running' THEN s.cpu END) AS running_cpus,
  GROUP_CONCAT(DISTINCT CASE WHEN s.state = 'Running' THEN s.core_type END) AS running_core_types,
  COALESCE(m.migrations, 0) AS migrations,
  COALESCE(m.cross_cluster_migrations, 0) AS cross_cluster_migrations
FROM states s
LEFT JOIN migrations m ON s.utid = m.utid
WHERE s.clipped_dur > 0
GROUP BY s.utid
HAVING total_cpu_ms > 0
ORDER BY total_cpu_ms DESC
LIMIT ${top_k|20}
