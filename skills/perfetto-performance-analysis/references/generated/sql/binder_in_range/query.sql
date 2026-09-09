-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_in_range.skill.yaml
-- Source SHA-256: 88af485b52bd4fc3a754df61300a43d34daf1c875e9870312a031e7e3595670b
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
SELECT
  client_process,
  server_process,
  COUNT(*) as call_count,
  SUM(client_dur) / 1e6 as total_client_ms,
  MAX(client_dur) / 1e6 as max_delay_ms,
  AVG(client_dur) / 1e6 as avg_delay_ms,
  SUM(CASE WHEN client_dur > 10000000 THEN 1 ELSE 0 END) as slow_calls
FROM android_binder_txns bt
JOIN effective_target_processes target ON bt.client_upid = target.upid
WHERE (${start_ts} IS NULL OR client_ts >= ${start_ts})
  AND (${end_ts} IS NULL OR client_ts < ${end_ts})
  AND (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR client_process = '${package}' OR client_process GLOB '${package}:*')
GROUP BY client_process, server_process
HAVING total_client_ms > 1
ORDER BY total_client_ms DESC
