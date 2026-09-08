-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 36f5184c4bd50b7001d0a1d14acaee52592734ad5771dec48bb5e811a7c66b96
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
frame_gpu AS (
  SELECT
    f.ts,
    f.dur,
    COALESCE(f.jank_type, 'None') as jank_type,
    (
      SELECT ROUND(g.gpu_freq / 1e6, 0)
      FROM android_gpu_frequency g
      WHERE g.ts <= f.ts
        AND g.ts + g.dur > f.ts
      LIMIT 1
    ) as gpu_freq_mhz
  FROM actual_frame_timeline_slice f
  LEFT JOIN process p ON f.upid = p.upid
  WHERE f.dur > 0
    AND (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR f.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR f.ts < ${end_ts})
    AND COALESCE(f.display_frame_token, f.surface_frame_token) IS NOT NULL
)
SELECT
  jank_type,
  COUNT(*) as frame_count,
  ROUND(AVG(gpu_freq_mhz), 0) as avg_gpu_freq_mhz,
  ROUND(AVG(dur) / 1e6, 2) as avg_frame_dur_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_frame_dur_ms,
  ROUND(MIN(gpu_freq_mhz), 0) || ' - ' || ROUND(MAX(gpu_freq_mhz), 0) || ' MHz' as gpu_freq_range
FROM frame_gpu
WHERE gpu_freq_mhz IS NOT NULL
GROUP BY jank_type
ORDER BY frame_count DESC
LIMIT 10
