-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_process_state_residency.skill.yaml
-- Source SHA-256: f785279fb41abf9e40451b7089d02655c17180229724e8a28759af866c6347cf
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS window_start,
    COALESCE(${end_ts}, trace_end()) AS window_end
),
intervals AS (
  SELECT upid, process_label AS process_name, state, state_rank, ts, open_dur AS dur
  FROM process_state_scoped_intervals
  WHERE state != 'EXITED'
),
clipped AS (
  SELECT
    i.*,
    MAX(MIN(i.ts + i.dur, b.window_end) - MAX(i.ts, b.window_start), 0) AS clipped_dur
  FROM intervals AS i
  CROSS JOIN bounds AS b
  WHERE i.ts < b.window_end AND i.ts + i.dur >= b.window_start
),
alive AS (
  SELECT upid, SUM(clipped_dur) AS alive_dur FROM clipped GROUP BY upid
)
SELECT
  c.process_name,
  c.upid,
  c.state,
  c.state_rank,
  ROUND(SUM(c.clipped_dur) / 1e6, 2) AS residency_ms,
  ROUND(100.0 * SUM(c.clipped_dur) / NULLIF(a.alive_dur, 0), 2) AS residency_pct,
  COUNT(*) AS interval_count,
  printf('%d', MIN(c.ts)) AS first_entered_ts
FROM clipped AS c
JOIN alive AS a USING (upid)
GROUP BY c.upid, c.state
ORDER BY c.process_name, c.upid, SUM(c.clipped_dur) DESC
