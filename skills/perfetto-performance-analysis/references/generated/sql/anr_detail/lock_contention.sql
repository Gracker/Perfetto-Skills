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
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts
),
clipped_contention AS (
  SELECT
    short_blocking_method,
    blocking_thread_name,
    short_blocked_method,
    blocked_thread_name,
    process_name,
    is_blocked_thread_main,
    waiter_count,
    MIN(CASE WHEN dur < 0 THEN aw.end_ts ELSE ts + dur END, aw.end_ts)
      - MAX(ts, aw.start_ts) AS clipped_ns
  FROM android_monitor_contention amc
  JOIN effective_target_processes target ON amc.upid = target.upid
  CROSS JOIN anr_window aw
  WHERE ts < aw.end_ts
    AND (CASE WHEN dur < 0 THEN aw.end_ts ELSE ts + dur END) > aw.start_ts
    AND (${__process_scope.upid} IS NOT NULL OR '${process_name}' = '' OR process_name = '${process_name}')
    AND is_blocked_thread_main = 1
    AND (
      MIN(CASE WHEN dur < 0 THEN aw.end_ts ELSE ts + dur END, aw.end_ts)
        - MAX(ts, aw.start_ts)
    ) >= 1000000  -- > 1ms inside the ANR window
)
SELECT
  short_blocking_method as blocking_method,
  blocking_thread_name,
  short_blocked_method as blocked_method,
  blocked_thread_name,
  process_name,
  CASE WHEN is_blocked_thread_main THEN 'MainThread' ELSE blocked_thread_name END as blocked_type,
  ROUND(clipped_ns / 1e6, 2) as wait_ms,
  waiter_count,
  -- 判断严重程度
  CASE
    WHEN clipped_ns / 1e6 > 1000 THEN 'critical'
    WHEN clipped_ns / 1e6 > 100 THEN 'warning'
    ELSE 'info'
  END as severity
FROM clipped_contention
ORDER BY clipped_ns DESC
LIMIT 10
