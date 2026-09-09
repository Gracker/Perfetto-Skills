-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/page_fault_in_range.skill.yaml
-- Source SHA-256: b4cce90c4fa90dd7d599a0771b7109f4f799ba81b09a84ffd6fdacb42ba08b26
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
    AND (t.tid = p.pid OR t.name = 'RenderThread' OR t.name LIKE '%Binder%')
),
memory_events AS (
  SELECT
    tt.thread_name,
    ts.dur,
    ts.blocked_function,
    CASE
      WHEN ts.blocked_function LIKE '%do_page_fault%' THEN 'page_fault'
      WHEN ts.blocked_function LIKE '%handle_mm_fault%' THEN 'page_fault'
      WHEN ts.blocked_function LIKE '%pf_%' THEN 'page_fault'
      WHEN ts.blocked_function LIKE '%__alloc_pages%' THEN 'alloc_pages'
      WHEN ts.blocked_function LIKE '%direct_reclaim%' THEN 'direct_reclaim'
      WHEN ts.blocked_function LIKE '%shrink_%' THEN 'memory_shrink'
      WHEN ts.blocked_function LIKE '%kswapd%' THEN 'kswapd'
      WHEN ts.blocked_function LIKE '%compaction%' THEN 'compaction'
      WHEN ts.blocked_function LIKE '%swap%' THEN 'swap'
      ELSE 'other_memory'
    END as fault_type
  FROM thread_state ts
  JOIN target_threads tt ON ts.utid = tt.utid
  WHERE (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
    AND ts.state IN ('D', 'DK')
    AND ts.blocked_function IS NOT NULL
    AND (ts.blocked_function LIKE '%page%'
         OR ts.blocked_function LIKE '%pf_%'
         OR ts.blocked_function LIKE '%alloc%'
         OR ts.blocked_function LIKE '%reclaim%'
         OR ts.blocked_function LIKE '%kswapd%'
         OR ts.blocked_function LIKE '%shrink%'
         OR ts.blocked_function LIKE '%compaction%'
         OR ts.blocked_function LIKE '%swap%')
)
SELECT
  thread_name,
  fault_type,
  COUNT(*) as count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms
FROM memory_events
WHERE fault_type != 'other_memory'
GROUP BY thread_name, fault_type
HAVING total_ms > 0.1
ORDER BY total_ms DESC
