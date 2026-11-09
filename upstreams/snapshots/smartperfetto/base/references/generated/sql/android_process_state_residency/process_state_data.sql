-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_process_state_residency.skill.yaml
-- Source SHA-256: 226abdc8bd617a35c5005014a5020538455aa88290a2d96fa911645bbb2387b1

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Framework process-state intervals (android.process_state, trace processors
-- after v58.2) for the requested process. Reads the private stdlib table
-- _android_process_state_intervals from the pinned v59.1 runtime. NONEXISTENT
-- and EXITED stay visible as lifecycle markers, but callers must exclude both
-- from alive time. An open interval (dur = -1) runs to trace end. The renamed
-- state_change_reason keeps the product's reason column; exit_reason is a
-- separate fact. process_label falls back to process.name, then upid.
-- A process matches by upid, exact name, `name:*` subprocess, or package.
process_state_scoped_intervals AS (
  SELECT
    i.*,
    i.state_change_reason AS reason,
    COALESCE(i.process_name, p.name, printf('upid:%d', i.upid)) AS process_label,
    IIF(i.dur < 0, trace_end() - i.ts, i.dur) AS open_dur,
    p.end_ts AS process_end_ts
  FROM _android_process_state_intervals AS i
  LEFT JOIN process AS p USING (upid)
  WHERE (${upid} IS NULL OR i.upid = ${upid})
    AND (
      '${process_name}' = ''
      OR COALESCE(i.process_name, p.name) = '${process_name}'
      OR COALESCE(i.process_name, p.name) GLOB '${process_name}:*'
      OR i.package_name = '${process_name}'
    )
)
,
events AS (
  SELECT COUNT(*) AS state_event_count, COUNT(DISTINCT upid) AS process_count
  FROM __intrinsic_android_process_state
),
matched AS (
  SELECT COUNT(DISTINCT upid) AS matched_process_count FROM process_state_scoped_intervals
)
SELECT
  e.state_event_count,
  e.process_count,
  m.matched_process_count,
  CASE
    WHEN e.state_event_count = 0 THEN 'no_process_state_data'
    WHEN m.matched_process_count = 0 THEN 'no_process_state_for_requested_process'
    ELSE 'available'
  END AS status
FROM events AS e
CROSS JOIN matched AS m
