-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid,
    CASE
      WHEN t.tid = p.pid THEN 'MainThread'
      WHEN t.name = 'RenderThread' THEN 'RenderThread'
      WHEN t.name LIKE 'Binder:%' THEN 'Binder'
      ELSE 'Other'
  END as thread_type
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (
      ${__process_scope.upid} IS NOT NULL
      OR (${upid} > 0 AND p.upid = ${upid})
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
