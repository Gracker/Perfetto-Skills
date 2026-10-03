-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: 16d9635bd76e3e596da0e0ef704764a78461c0e4e531aa3e272757d03a8cbba4

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
