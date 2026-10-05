-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: cdf73ddd0bc9f5f3d8d5cb1b130d4ac79a5a0f132ec3f473fdcd40b76e6309e5

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
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL
      OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND t.tid = p.pid
),
slice_with_self AS (
  SELECT
    s.id,
    s.name as slice_name,
    MIN(s.ts + s.dur, ${end_ts}) - MAX(s.ts, ${start_ts}) as clipped_dur,
    (MIN(s.ts + s.dur, ${end_ts}) - MAX(s.ts, ${start_ts}))
      - COALESCE((
          SELECT SUM(
            MIN(c.ts + c.dur, MIN(s.ts + s.dur, ${end_ts}))
            - MAX(c.ts, MAX(s.ts, ${start_ts}))
          )
          FROM slice c
          WHERE c.parent_id = s.id
            AND c.ts < ${end_ts}
            AND c.ts + c.dur > ${start_ts}
        ), 0) as self_dur
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN main_thread mt ON tt.utid = mt.utid
  WHERE s.ts < ${end_ts}
    AND s.ts + s.dur > ${start_ts}
),
agg AS (
  SELECT
    slice_name,
    COUNT(*) as count,
    ROUND(SUM(clipped_dur) / 1e6, 2) as total_ms,
    ROUND(SUM(self_dur) / 1e6, 2) as self_ms,
    ROUND(AVG(clipped_dur) / 1e6, 2) as avg_ms,
    ROUND(MAX(clipped_dur) / 1e6, 2) as max_ms,
    ROUND(100.0 * SUM(clipped_dur) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as percent,
    ROUND(100.0 * SUM(self_dur) / NULLIF(${end_ts} - ${start_ts}, 0), 1) as self_percent,
    CASE
      WHEN lower(slice_name) IN ('clienttransactionexecuted', 'activitystart', 'bindapplication') THEN 1
      WHEN lower(slice_name) GLOB 'performcreate:*' THEN 1
      WHEN lower(slice_name) GLOB 'performresume*' THEN 1
      WHEN lower(slice_name) GLOB 'activitythreadmain*' THEN 1
      ELSE 0
    END as is_framework_wrapper
  FROM slice_with_self
  WHERE clipped_dur >= 1000000
  GROUP BY slice_name
)
SELECT
  slice_name,
  count,
  total_ms,
  self_ms,
  avg_ms,
  max_ms,
  percent,
  self_percent,
  is_framework_wrapper
FROM agg
ORDER BY is_framework_wrapper ASC, self_ms DESC
LIMIT 5
