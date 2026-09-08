-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_blocking_in_range.skill.yaml
-- Source SHA-256: 5c7bb147c3adc2ccd2e734f970b9b8ddc51d65f05e9f84c85be092b0130a0a9d
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
target_main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND t.tid = p.pid  -- 主线程
)
SELECT
  bt.server_process,
  COALESCE(bt.aidl_name, bt.server_thread, 'unknown') as interface,
  COUNT(*) as call_count,
  ROUND(SUM(bt.client_dur) / 1e6, 2) as total_block_ms,
  ROUND(SUM(bt.server_dur) / 1e6, 2) as server_exec_ms,
  ROUND(MAX(bt.client_dur) / 1e6, 2) as max_block_ms,
  MAX(CASE WHEN bt.client_utid IN (SELECT utid FROM target_main_thread) THEN 1 ELSE 0 END) as is_main_blocked
FROM android_binder_txns bt
JOIN effective_target_processes target ON bt.client_upid = target.upid
WHERE (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
  AND bt.is_sync = 1  -- 只关注同步调用
  AND (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR bt.client_process = '${package}' OR bt.client_process GLOB '${package}:*')
  AND bt.client_dur > 500000  -- > 0.5ms
GROUP BY bt.server_process, interface
HAVING total_block_ms > 0.5
ORDER BY total_block_ms DESC
LIMIT 10
