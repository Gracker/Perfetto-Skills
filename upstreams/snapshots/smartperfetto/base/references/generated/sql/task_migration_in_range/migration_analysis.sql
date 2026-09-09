-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/task_migration_in_range.skill.yaml
-- Source SHA-256: 6b439d1de33342825c0e07b756b2e0b4ee97eb56287f7df8d9312a9a14ce14f2
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
  SELECT t.utid, t.name as thread_name
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.tid = p.pid OR t.name = 'RenderThread')
),
cpu_switches AS (
  SELECT
    tt.thread_name,
    ts.cpu,
    ct.core_type,
    LAG(ts.cpu) OVER (PARTITION BY tt.utid ORDER BY ts.ts) as prev_cpu,
    LAG(ct.core_type) OVER (PARTITION BY tt.utid ORDER BY ts.ts) as prev_core_type,
    ts.dur
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts >= ${start_ts} AND ts.ts < ${end_ts}
    AND ts.state = 'Running'
)
SELECT
  thread_name,
  SUM(CASE WHEN cpu != prev_cpu AND prev_cpu IS NOT NULL THEN 1 ELSE 0 END) as migration_count,
  SUM(CASE WHEN core_type = 'little' AND prev_core_type = 'big' THEN 1 ELSE 0 END) as big_to_little,
  SUM(CASE WHEN core_type = 'big' AND prev_core_type = 'little' THEN 1 ELSE 0 END) as little_to_big,
  ROUND(100.0 * SUM(CASE WHEN core_type = 'big' THEN dur ELSE 0 END) / NULLIF(SUM(dur), 0), 1) as big_core_pct,
  COUNT(DISTINCT cpu) as unique_cpus
FROM cpu_switches
GROUP BY thread_name
HAVING migration_count > 0
ORDER BY migration_count DESC
