-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/sched_latency_in_range.skill.yaml
-- Source SHA-256: 1c7cccd8cec4d46d8e0268e09dc0dd68c019b0783e5c575a13de4b01254924d0
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
target_threads AS (
  SELECT t.utid, t.name as thread_name, p.pid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name LIKE '%UI%')
),
runnable_states AS (
  SELECT tt.thread_name, ts.dur
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND ts.state = 'R'  -- Runnable but not running
    AND ts.dur > 10000  -- > 10us to be meaningful
)
SELECT
  thread_name,
  COUNT(*) as runnable_count,
  ROUND(SUM(dur) / 1e6, 2) as total_runnable_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_latency_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_latency_ms,
  SUM(CASE WHEN dur > 2000000 THEN 1 ELSE 0 END) as long_wait_count
FROM runnable_states
GROUP BY thread_name
HAVING total_runnable_ms > 0.1
ORDER BY total_runnable_ms DESC
