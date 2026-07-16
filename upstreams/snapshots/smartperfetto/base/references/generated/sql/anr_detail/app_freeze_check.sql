-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid,
    CASE
      WHEN t.tid = p.pid THEN 'MainThread'
      WHEN t.name = 'RenderThread' THEN 'RenderThread'
      WHEN t.name LIKE 'Binder:%' THEN 'Binder'
      ELSE 'Other'
    END as thread_type
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name LIKE 'Binder:%')
),
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts
),
thread_activity AS (
  SELECT
    tt.thread_type,
    SUM(CASE WHEN ts.state = 'Running' THEN
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ELSE 0 END) as running_ns,
    SUM(
      MIN(CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END, aw.end_ts)
        - MAX(ts.ts, aw.start_ts)
    ) as total_ns
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  CROSS JOIN anr_window aw
  WHERE ts.ts < aw.end_ts
    AND (CASE WHEN ts.dur < 0 THEN aw.end_ts ELSE ts.ts + ts.dur END) > aw.start_ts
  GROUP BY tt.thread_type
)
SELECT
  thread_type,
  ROUND(running_ns / 1e6, 2) as running_ms,
  ROUND(total_ns / 1e6, 2) as total_ms,
  ROUND(100.0 * running_ns / NULLIF(total_ns, 0), 1) as activity_pct,
  CASE
    WHEN 100.0 * running_ns / NULLIF(total_ns, 0) < 5 THEN 'frozen'
    WHEN 100.0 * running_ns / NULLIF(total_ns, 0) < 20 THEN 'low_activity'
    ELSE 'active'
  END as status
FROM thread_activity
ORDER BY
  CASE thread_type
    WHEN 'MainThread' THEN 1
    WHEN 'RenderThread' THEN 2
    WHEN 'Binder' THEN 3
    ELSE 4
  END
