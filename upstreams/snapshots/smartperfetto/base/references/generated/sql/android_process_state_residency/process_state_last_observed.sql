-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_process_state_residency.skill.yaml
-- Source SHA-256: f785279fb41abf9e40451b7089d02655c17180229724e8a28759af866c6347cf
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Framework process-state intervals (android.process_state, trace processors
-- after v58.2) for the requested process. Reads the private stdlib table
-- _android_process_state_intervals and normalizes the shapes it has had:
-- NONEXISTENT rows (pre-birth placeholders) are dropped, and an open interval
-- (dur = -1, e.g. EXITED after death) runs to the end of the trace. EXITED
-- stays in so callers can report it as a lifecycle marker; exclude it from
-- alive time. process_label falls back to process.name, then upid.
-- A process matches by upid, exact name, `name:*` subprocess, or package.
process_state_scoped_intervals AS (
  SELECT
    i.*,
    COALESCE(i.process_name, p.name, printf('upid:%d', i.upid)) AS process_label,
    IIF(i.dur < 0, trace_end() - i.ts, i.dur) AS open_dur,
    p.end_ts AS process_end_ts
  FROM _android_process_state_intervals AS i
  LEFT JOIN process AS p USING (upid)
  WHERE i.state != 'NONEXISTENT'
    AND (${upid} IS NULL OR i.upid = ${upid})
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
  WHERE state != 'EXITED'
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
