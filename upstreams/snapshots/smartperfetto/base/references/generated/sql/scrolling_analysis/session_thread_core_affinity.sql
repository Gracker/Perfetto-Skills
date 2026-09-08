-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 6ebd984e1b34cb456d5fa410b4e2308e350c5854086ec1e06ff58b4c80c5ef4f
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
thread_runs AS (
  SELECT
    CASE WHEN t.tid = p.pid THEN 'MainThread' ELSE t.name END as thread_name,
    COALESCE(ct.core_type, 'unknown') as core_type,
    SUM(ts.dur) as run_dur_ns
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN effective_target_processes p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE (
    ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}'
    OR p.name GLOB '${package}:*'
  )
    AND p.name NOT LIKE '/system/%'
    -- With no target package the clause above accepts any process, and
    -- the system UI is the one most likely to be drawing while the target
    -- app draws nothing. Its frames are punctual, so they read back as
    -- flawless scrolling for an app that produced no frames at all: one
    -- device reported 31fps SystemUI frames as "优秀", another rated a
    -- 5-frame notification-shade window. Anyone analysing the system UI
    -- deliberately names it and keeps these rows.
    AND ('${package}' != '' OR p.name NOT LIKE 'com.android.systemui%')
    AND ts.state = 'Running'
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND (t.tid = p.pid OR t.name IN ('RenderThread', 'GPU completion', 'hwuiTask0', 'hwuiTask1'))
  GROUP BY thread_name, core_type
)
SELECT
  thread_name,
  core_type,
  ROUND(run_dur_ns / 1e6, 2) as run_ms,
  ROUND(100.0 * run_dur_ns / NULLIF(SUM(run_dur_ns) OVER (PARTITION BY thread_name), 0), 1) as pct
FROM thread_runs
ORDER BY
  CASE thread_name
    WHEN 'MainThread' THEN 1
    WHEN 'RenderThread' THEN 2
    WHEN 'GPU completion' THEN 3
    ELSE 4
  END,
  run_dur_ns DESC
