-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
-- Source SHA-256: 3c4b708b7b84c9206463877bf914275bb2d48df15eef7c821ebe6eeaf4a8e263
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH
raw_input AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS raw_start_ts,
    COALESCE(${end_ts}, trace_end()) AS raw_end_ts
),
input AS (
  SELECT
    MIN(raw_start_ts, raw_end_ts) AS start_ts,
    MAX(raw_start_ts, raw_end_ts) AS end_ts
  FROM raw_input
),
cpu_capacity AS (
  SELECT MAX(cpu_count, 1) AS cpu_count
  FROM (
    SELECT COUNT(DISTINCT cpu) AS cpu_count
    FROM sched_slice
  )
),
runnable AS (
  SELECT
    MAX(ts.ts, input.start_ts) AS start_ts,
    MIN(ts.ts + IIF(ts.dur = -1, trace_end() - ts.ts, ts.dur), input.end_ts) AS end_ts
  FROM thread_state ts, input
  WHERE ts.state IN ('R', 'R+')
    AND IIF(ts.dur = -1, trace_end() - ts.ts, ts.dur) > 0
    AND ts.ts < input.end_ts
    AND ts.ts + IIF(ts.dur = -1, trace_end() - ts.ts, ts.dur) > input.start_ts
),
events AS (
  SELECT start_ts AS ts, 1 AS delta
  FROM runnable
  WHERE end_ts > start_ts
  UNION ALL
  SELECT end_ts AS ts, -1 AS delta
  FROM runnable
  WHERE end_ts > start_ts
  UNION ALL
  SELECT start_ts AS ts, 0 AS delta
  FROM input
  UNION ALL
  SELECT end_ts AS ts, 0 AS delta
  FROM input
),
points AS (
  SELECT ts, SUM(delta) AS delta
  FROM events
  GROUP BY ts
),
timeline AS (
  SELECT
    ts,
    SUM(delta) OVER (
      ORDER BY ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS runnable_thread_count,
    LEAD(ts) OVER (ORDER BY ts) AS next_ts
  FROM points
),
overlapped AS (
  SELECT
    runnable_thread_count,
    next_ts - ts AS overlap_dur
  FROM timeline
  WHERE next_ts > ts
),
ranked AS (
  SELECT
    runnable_thread_count,
    overlap_dur,
    SUM(overlap_dur) OVER () AS total_dur,
    SUM(overlap_dur) OVER (
      ORDER BY runnable_thread_count
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_dur
  FROM overlapped
)
SELECT
  COUNT(*) AS samples,
  COALESCE(ROUND(SUM(runnable_thread_count * overlap_dur) / NULLIF(SUM(overlap_dur), 0), 2), 0) AS avg_runnable_threads,
  COALESCE((
    SELECT MIN(runnable_thread_count)
    FROM ranked
    WHERE cumulative_dur >= total_dur * 0.95
  ), 0) AS p95_runnable_threads,
  COALESCE(MAX(runnable_thread_count), 0) AS max_runnable_threads,
  cpu_capacity.cpu_count,
  COALESCE(ROUND(SUM(CASE WHEN runnable_thread_count >= 4 THEN overlap_dur ELSE 0 END) / 1e6, 2), 0) AS runnable_wait_ge4_ms,
  COALESCE(ROUND(SUM(CASE WHEN runnable_thread_count > cpu_capacity.cpu_count THEN overlap_dur ELSE 0 END) / 1e6, 2), 0) AS over_cpu_capacity_ms,
  COALESCE(ROUND(SUM(CASE WHEN runnable_thread_count > cpu_capacity.cpu_count THEN overlap_dur ELSE 0 END) / 1e6, 2), 0) AS pressure_weighted_ms
FROM overlapped, cpu_capacity
