-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 7ec44d892abb05141d0c58bfb05944911a22d8a6d4252fc95aa9b12c5f4f800a
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts)) as end_ts
  FROM slice
),
-- 动态检测 VSync 周期（VSYNC-sf 中位数优先，expected_frame 回退）
vsync_config AS (
  SELECT CAST(COALESCE(
    (SELECT PERCENTILE(interval_ns, 0.5)
     FROM (
       SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
       FROM counter c
       JOIN counter_track t ON c.track_id = t.id
       WHERE t.name = 'VSYNC-sf'
         AND c.ts >= (SELECT start_ts FROM time_bounds)
         AND c.ts <= (SELECT end_ts FROM time_bounds)
     ) WHERE interval_ns > 5500000 AND interval_ns < 50000000),
    (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
     FROM expected_frame_timeline_slice
     WHERE dur > 5000000 AND dur < 50000000
       AND ts >= (SELECT start_ts FROM time_bounds)
       AND ts <= (SELECT end_ts FROM time_bounds)),
    16666667
  ) AS INTEGER) as vsync_period_ns
),
fence_slices AS (
  SELECT
    s.name,
    s.dur
  FROM slice s
  WHERE (s.name GLOB '*fence*'
         OR s.name GLOB '*Fence*'
         OR s.name GLOB '*GPU completion*'
         OR s.name GLOB '*Waiting for GPU*')
    -- Note: eglSwapBuffers excluded — it measures buffer queue fullness
    -- (buffer stuffing), not GPU fence completion time
    AND s.ts >= (SELECT start_ts FROM time_bounds)
    AND s.ts <= (SELECT end_ts FROM time_bounds)
    AND s.dur > 0
)
SELECT
  COUNT(*) as total_fence_waits,
  ROUND(SUM(dur) / 1e6, 2) as total_wait_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_wait_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_wait_ms,
  ROUND(PERCENTILE(dur, 0.95) / 1e6, 2) as p95_wait_ms,
  ROUND((SELECT vsync_period_ns FROM vsync_config) / 1e6, 2) as vsync_period_ms,
  -- 使用动态 VSync 周期
  COUNT(CASE WHEN dur > (SELECT vsync_period_ns FROM vsync_config) THEN 1 END) as waits_over_vsync,
  CASE
    -- 平均等待超过 VSync 周期的 50%
    WHEN AVG(dur) > (SELECT vsync_period_ns FROM vsync_config) * 0.5 THEN 'GPU_BOUND'
    WHEN COUNT(CASE WHEN dur > (SELECT vsync_period_ns FROM vsync_config) THEN 1 END) > COUNT(*) * 0.1 THEN 'GPU_OCCASIONAL_SLOW'
    ELSE 'NORMAL'
  END as gpu_status
FROM fence_slices
