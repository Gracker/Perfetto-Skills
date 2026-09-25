-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_render_in_range.skill.yaml
-- Source SHA-256: 41c5baba37f722b6109d1a1058f99a23195d9b80ef96f0fade4e979a8ed860b0
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
gpu_slices AS (
  SELECT
    s.name,
    CASE WHEN s.dur >= 0 THEN
      MIN(s.ts + s.dur, COALESCE(${end_ts}, trace_end())) -
      MAX(s.ts, COALESCE(${start_ts}, trace_start()))
    END AS dur,
    CASE WHEN s.dur < 0 THEN 1 ELSE 0 END AS censored,
    CASE
      WHEN s.name GLOB '*DrawFrame*' OR s.name GLOB '*doFrame*' THEN 'Draw Frame'
      WHEN s.name GLOB '*fence*signal*' OR s.name GLOB '*Fence*signal*' THEN 'Fence Signal'
      WHEN s.name GLOB '*fence*wait*' OR s.name GLOB '*waitForFence*' THEN 'Fence Wait'
      WHEN s.name GLOB '*eglSwap*' THEN 'EGL SwapBuffers'
      WHEN s.name GLOB '*flush*' OR s.name GLOB '*Flush*' THEN 'GPU Flush'
      WHEN s.name GLOB '*queueBuffer*' THEN 'Queue Buffer'
      WHEN s.name GLOB '*dequeueBuffer*' THEN 'Dequeue Buffer'
      WHEN s.name GLOB '*GPU*' THEN 'GPU Other'
      WHEN s.name GLOB '*RenderThread*' THEN 'RenderThread'
      ELSE NULL
    END as operation
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE s.ts < COALESCE(${end_ts}, trace_end())
    AND (s.dur < 0 OR s.ts + s.dur > COALESCE(${start_ts}, trace_start()))
    AND COALESCE(${end_ts}, trace_end()) > COALESCE(${start_ts}, trace_start())
    AND (
      (
        p.upid IN (SELECT upid FROM effective_target_processes)
        AND (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
      )
      OR p.name = 'surfaceflinger'
    )
    AND (s.dur > 10000 OR s.dur < 0)  -- Completed > 10us or unknown end.
)
SELECT
  operation,
  COUNT(*) as count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_ms,
  SUM(censored) AS censored_slice_count,
  'sum_of_clipped_completed_operation_slices_not_gpu_busy_time;_unknown_ends_excluded' AS duration_basis
FROM gpu_slices
WHERE operation IS NOT NULL
GROUP BY operation
ORDER BY total_ms DESC
