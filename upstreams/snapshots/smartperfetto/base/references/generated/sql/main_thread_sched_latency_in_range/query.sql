-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/main_thread_sched_latency_in_range.skill.yaml
-- Source SHA-256: c0a7c90db402980de38c10ae00ada63133dd05269323e952bc13f4279c9b1fdd
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
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND t.tid = p.pid
)
SELECT
  'MainThread' as thread_name,
  COUNT(*) as runnable_count,
  ROUND(SUM(ts.dur) / 1e6, 2) as total_runnable_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) as avg_latency_ms,
  SUM(CASE WHEN ts.dur > 2000000 THEN 1 ELSE 0 END) as long_wait_count,
  SUM(CASE WHEN ts.dur > 8000000 THEN 1 ELSE 0 END) as severe_count
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
  AND ts.state IN ('R', 'R+')
GROUP BY 1
HAVING total_runnable_ms > 0.01
