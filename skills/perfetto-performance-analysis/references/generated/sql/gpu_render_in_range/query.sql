-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_render_in_range.skill.yaml
-- Source SHA-256: 8bb5be71c0b5a94ecc3eb2ce24af291332227634bafef0a5423144dfcd48dab6
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH gpu_slices AS (
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
    AND (p.name GLOB '${package}*' OR '${package}' = '' OR p.name = 'surfaceflinger')
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
