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
ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY ts DESC) AS recency
  FROM process_state_scoped_intervals
  WHERE state NOT IN ('EXITED', 'NONEXISTENT')
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
SELECT
  process_label AS process_name,
  upid,
  state AS last_state,
  printf('%d', ts) AS entered_ts,
  IIF(process_end_ts IS NULL, NULL, printf('%d', process_end_ts)) AS process_end_ts,
  IIF(process_end_ts IS NULL, 'alive_at_trace_end', 'process_ended') AS lifecycle
FROM ranked
WHERE recency = 1
ORDER BY process_name, upid
