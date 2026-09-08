-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: 283e74c341c76d3959624287f046bcc7f85e2b7b1cbe1edfab07c544a01660af
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
  WHERE (
      ${__process_scope.upid} IS NOT NULL
      OR (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts
)
SELECT
  COALESCE(waker_thread.name, 'unknown') AS waker_thread,
  COALESCE(waker_process.name, 'kernel') AS waker_process,
  ts.blocked_function,
  COUNT(*) AS wakeup_count,
  ROUND(AVG(ts.dur) / 1e6, 2) AS avg_sleep_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) AS max_sleep_ms,
  ROUND(SUM(ts.dur) / 1e6, 2) AS total_sleep_ms
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
CROSS JOIN anr_window aw
LEFT JOIN thread waker_thread ON ts.waker_utid = waker_thread.utid
LEFT JOIN process waker_process ON waker_thread.upid = waker_process.upid
WHERE ts.ts >= aw.start_ts
  AND ts.ts < aw.end_ts
  AND ts.state IN ('S', 'D', 'I')
  AND ts.dur >= 1000000  -- > 1ms
GROUP BY waker_thread.name, waker_process.name, ts.blocked_function
ORDER BY total_sleep_ms DESC
LIMIT 10
