-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/present_fence_timing.skill.yaml
-- Source SHA-256: 13da4eb5934736e0b60cb39f01f7e306b873de90f9f210090bb4dcd3a0a62c7d
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts + dur)) as end_ts
  FROM actual_frame_timeline_slice
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
fence_data AS (
  SELECT
    s.ts,
    s.dur,
    s.name,
    p.name as process_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (s.name GLOB '*PresentFence*'
         OR s.name GLOB '*present*fence*'
         OR s.name GLOB '*GPU completion*'
         OR s.name GLOB '*waiting for GPU*'
         OR s.name GLOB '*Waiting for GPU*')
    AND s.ts >= (SELECT start_ts FROM time_bounds)
    AND s.ts <= (SELECT end_ts FROM time_bounds)
),
fence_stats AS (
  SELECT
    COUNT(*) as total_fences,
    AVG(dur) as avg_wait_ns,
    MAX(dur) as max_wait_ns,
    MIN(dur) as min_wait_ns,
    (SELECT vsync_period_ns FROM vsync_config) as vsync_period_ns,
    COUNT(CASE WHEN dur > 1000000 THEN 1 END) as slow_fences_1ms,
    COUNT(CASE WHEN dur > 5000000 THEN 1 END) as slow_fences_5ms,
    -- 使用动态 VSync 周期
    COUNT(CASE WHEN dur > (SELECT vsync_period_ns FROM vsync_config) THEN 1 END) as slow_fences_vsync
  FROM fence_data
)
SELECT
  total_fences,
  ROUND(avg_wait_ns / 1e6, 2) as avg_wait_ms,
  ROUND(max_wait_ns / 1e6, 2) as max_wait_ms,
  ROUND(min_wait_ns / 1e6, 2) as min_wait_ms,
  slow_fences_1ms,
  slow_fences_5ms,
  slow_fences_vsync,
  ROUND(100.0 * slow_fences_vsync / NULLIF(total_fences, 0), 2) as slow_rate_pct,
  ROUND(vsync_period_ns / 1e6, 2) as vsync_period_ms,
  CASE
    -- 使用动态阈值：平均等待超过 VSync 周期的 50%
    WHEN avg_wait_ns > vsync_period_ns * 0.5 THEN 'GPU_BOUND'
    WHEN slow_fences_vsync > total_fences * 0.1 THEN 'GPU_OCCASIONAL_SLOW'
    ELSE 'NORMAL'
  END as gpu_status
FROM fence_stats
