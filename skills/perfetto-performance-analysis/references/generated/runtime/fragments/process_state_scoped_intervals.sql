-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/process_state_scoped_intervals.sql
-- Source SHA-256: cf1aad975c1eb4bd0d0d23caf61ea6a7b24ff262141c2c04335d6508cb163f18
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
