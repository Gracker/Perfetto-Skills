-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 36f5184c4bd50b7001d0a1d14acaee52592734ad5771dec48bb5e811a7c66b96
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  p.name as process_name,
  ROUND(MAX(gm.gpu_memory) / 1024.0 / 1024.0, 2) as max_gpu_memory_mb,
  ROUND(AVG(gm.gpu_memory) / 1024.0 / 1024.0, 2) as avg_gpu_memory_mb,
  ROUND(MIN(gm.gpu_memory) / 1024.0 / 1024.0, 2) as min_gpu_memory_mb,
  ROUND((MAX(gm.gpu_memory) - MIN(gm.gpu_memory)) / 1024.0 / 1024.0, 2) as memory_change_mb
FROM android_gpu_memory_per_process gm
JOIN process p ON gm.upid = p.upid
WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR gm.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR gm.ts < ${end_ts})
GROUP BY p.name
ORDER BY max_gpu_memory_mb DESC
LIMIT 15
