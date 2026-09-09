-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 2dcba698d9cc63e045e9346afc44cab60148cf55a58161bf0378383d624af4ff
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
main_quadrant AS (
  SELECT
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.dur ELSE 0 END) as q1_ns,
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.dur ELSE 0 END) as q2_ns,
    SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) as q3_ns,
    SUM(CASE WHEN ts.state IN ('D', 'DK') THEN ts.dur ELSE 0 END) as q4a_ns,
    SUM(CASE WHEN ts.state IN ('S', 'I') THEN ts.dur ELSE 0 END) as q4b_ns,
    SUM(ts.dur) as total_ns
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
    AND t.tid = p.pid
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
),
render_quadrant AS (
  SELECT
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.dur ELSE 0 END) as q1_ns,
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.dur ELSE 0 END) as q2_ns,
    SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) as q3_ns,
    SUM(CASE WHEN ts.state IN ('D', 'DK') THEN ts.dur ELSE 0 END) as q4a_ns,
    SUM(CASE WHEN ts.state IN ('S', 'I') THEN ts.dur ELSE 0 END) as q4b_ns,
    SUM(ts.dur) as total_ns
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
    AND t.name = 'RenderThread'
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
)
SELECT 'MainThread' as thread,
  ROUND(100.0 * q1_ns / NULLIF(total_ns, 0), 1) as q1_big_pct,
  ROUND(100.0 * q2_ns / NULLIF(total_ns, 0), 1) as q2_little_pct,
  ROUND(100.0 * q3_ns / NULLIF(total_ns, 0), 1) as q3_runnable_pct,
  ROUND(100.0 * q4a_ns / NULLIF(total_ns, 0), 1) as q4a_io_pct,
  ROUND(100.0 * q4b_ns / NULLIF(total_ns, 0), 1) as q4b_sleep_pct,
  ROUND(total_ns / 1e6, 2) as total_ms
FROM main_quadrant
UNION ALL
SELECT 'RenderThread' as thread,
  ROUND(100.0 * q1_ns / NULLIF(total_ns, 0), 1) as q1_big_pct,
  ROUND(100.0 * q2_ns / NULLIF(total_ns, 0), 1) as q2_little_pct,
  ROUND(100.0 * q3_ns / NULLIF(total_ns, 0), 1) as q3_runnable_pct,
  ROUND(100.0 * q4a_ns / NULLIF(total_ns, 0), 1) as q4a_io_pct,
  ROUND(100.0 * q4b_ns / NULLIF(total_ns, 0), 1) as q4b_sleep_pct,
  ROUND(total_ns / 1e6, 2) as total_ms
FROM render_quadrant
