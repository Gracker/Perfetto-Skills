-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 9e44f27b6343d60763ebf83af07b3dd5c2d9c22a357c8f8527c54a3f67b5e497

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
  'App接收' as stage,
  printf('%d', s.ts) as start_ts,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  t.name as thread_name,
  s.name as detail
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN effective_target_processes p ON t.upid = p.upid
WHERE (${__process_scope.upid} IS NOT NULL
    OR '${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
  AND (s.name GLOB '*deliverInput*' OR s.name GLOB 'aq:pending:deliver*' OR s.name GLOB '*InputEvent*')
  AND s.ts >= (${event_ts} - 10000000)
  AND s.ts <= (${event_end_ts} + 10000000)
ORDER BY s.ts
LIMIT 20
