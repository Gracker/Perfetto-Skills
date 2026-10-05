-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thread_affinity_violation.skill.yaml
-- Source SHA-256: c6d2edaaa916a159e69330f72fc2845056d18fd1bc2df190b2cec25c01962309

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
  SELECT
    t.utid,
    t.name as thread_name,
    p.name as process_name,
    p.pid,
    t.tid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL
      OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (
      t.tid = p.pid
      OR t.name = 'RenderThread'
      OR t.name GLOB '*Hwui*'
    )
),
sched_runs AS (
  SELECT
    s.utid,
    s.ts,
    s.cpu,
    tt.thread_name,
    tt.process_name
  FROM sched s
  JOIN target_threads tt ON s.utid = tt.utid
  WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
annotated AS (
  SELECT
    *,
    CASE
      WHEN LAG(cpu) OVER (PARTITION BY utid ORDER BY ts) IS NULL THEN 0
      WHEN LAG(cpu) OVER (PARTITION BY utid ORDER BY ts) != cpu THEN 1
      ELSE 0
    END as migrated
  FROM sched_runs
)
SELECT
  process_name,
  thread_name,
  COUNT(*) as run_samples,
  COUNT(DISTINCT cpu) as distinct_cpus,
  SUM(migrated) as migration_count,
  ROUND(100.0 * SUM(migrated) / NULLIF(COUNT(*), 0), 1) as migration_ratio_pct,
  CASE
    WHEN 100.0 * SUM(migrated) / NULLIF(COUNT(*), 0) >= ${migration_ratio_threshold|25} THEN 1
    ELSE 0
  END as affinity_violation
FROM annotated
GROUP BY process_name, thread_name
ORDER BY migration_ratio_pct DESC
