-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_render_in_range.skill.yaml
-- Source SHA-256: 1c142b8dbc84b47518922a8a37b43c85c1e3e887ad5bfc61179c1710dce9c286
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
,
gpu_slices AS (
  SELECT
    s.name,
    s.dur,
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
  WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts}) AND (${end_ts} IS NULL OR s.ts < ${end_ts})
    AND (
      (
        p.upid IN (SELECT upid FROM effective_target_processes)
        AND (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
      )
      OR p.name = 'surfaceflinger'
    )
    AND s.dur > 10000  -- > 10us
)
SELECT
  operation,
  COUNT(*) as count,
  ROUND(SUM(dur) / 1e6, 2) as total_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_ms
FROM gpu_slices
WHERE operation IS NOT NULL
GROUP BY operation
HAVING total_ms > 0.1
ORDER BY total_ms DESC
