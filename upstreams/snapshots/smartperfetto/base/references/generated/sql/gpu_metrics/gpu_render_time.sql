-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 7ec44d892abb05141d0c58bfb05944911a22d8a6d4252fc95aa9b12c5f4f800a
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts)) as end_ts
  FROM slice
),
gpu_slices AS (
  SELECT
    s.name,
    s.dur,
    s.ts
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE (s.name GLOB '*GPU*'
         OR s.name GLOB '*gpu*'
         OR s.name GLOB '*Render*Pass*'
         OR s.name GLOB '*Draw*Call*'
         OR s.name GLOB '*Shader*'
         OR s.name GLOB '*fence*signal*'
         OR s.name GLOB '*vkQueue*'
         OR s.name GLOB '*gl*Draw*')
    -- Exclude CPU-side rendering slices (RenderThread, DrawFrame on main thread)
    AND t.name NOT IN ('RenderThread', 'GPU completion', 'hwc_retire')
    AND s.name NOT GLOB 'DrawFrame*'
    AND s.name NOT GLOB 'RenderThread*'
    -- Exclude jank classification markers (CPU-side, not actual GPU work)
    AND s.name NOT GLOB '*DEADLINE*'
    AND s.name NOT GLOB '*MISSED*'
    AND s.ts >= (SELECT start_ts FROM time_bounds)
    AND s.ts <= (SELECT end_ts FROM time_bounds)
    AND s.dur > 0
)
SELECT
  name as gpu_operation,
  COUNT(*) as occurrence_count,
  ROUND(SUM(dur) / 1e6, 2) as total_time_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_time_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_time_ms,
  ROUND(PERCENTILE(dur, 0.95) / 1e6, 2) as p95_time_ms
FROM gpu_slices
GROUP BY name
ORDER BY total_time_ms DESC
