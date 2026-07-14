-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH anr_window AS (
  SELECT
    ${anr_ctx.data[0].anr_ts} - ${anr_ctx.data[0].timeout_ns} AS start_ts,
    ${anr_ctx.data[0].anr_ts} AS end_ts,
    ${anr_ctx.data[0].timeout_ns} AS window_ns
),
cpu_info AS (
  SELECT cpu_id as cpu, core_type
  FROM _cpu_topology
),
cpu_time AS (
  SELECT
    ss.cpu,
    COALESCE(c.core_type, 'unknown') as core_type,
    SUM(
      MIN(CASE WHEN ss.dur < 0 THEN aw.end_ts ELSE ss.ts + ss.dur END, aw.end_ts)
        - MAX(ss.ts, aw.start_ts)
    ) as active_ns
  FROM sched_slice ss
  CROSS JOIN anr_window aw
  LEFT JOIN cpu_info c ON ss.cpu = c.cpu
  WHERE ss.ts < aw.end_ts
    AND (CASE WHEN ss.dur < 0 THEN aw.end_ts ELSE ss.ts + ss.dur END) > aw.start_ts
  GROUP BY ss.cpu
),
totals AS (
  SELECT
    core_type,
    COUNT(*) as core_count,
    SUM(active_ns) as total_active_ns,
    (SELECT window_ns FROM anr_window) as window_ns
  FROM cpu_time
  GROUP BY core_type
)
SELECT
  core_type,
  core_count,
  ROUND(total_active_ns / 1e6, 2) as total_active_ms,
  ROUND(100.0 * total_active_ns / (window_ns * core_count), 1) as avg_util_pct,
  CASE
    WHEN 100.0 * total_active_ns / (window_ns * core_count) > 90 THEN 'overloaded'
    WHEN 100.0 * total_active_ns / (window_ns * core_count) > 70 THEN 'busy'
    ELSE 'normal'
  END as status
FROM totals
ORDER BY core_type DESC
