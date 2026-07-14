-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_analysis.skill.yaml
-- Source SHA-256: c99bd1159e7f337b0d5dd490100f66e9134271d55a7bbf0362ebf64d3a1d9602
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  p.name as process_name,
  ROUND(MAX(gm.gpu_memory) / 1024.0 / 1024.0, 2) as max_gpu_memory_mb,
  ROUND(AVG(gm.gpu_memory) / 1024.0 / 1024.0, 2) as avg_gpu_memory_mb,
  ROUND(MIN(gm.gpu_memory) / 1024.0 / 1024.0, 2) as min_gpu_memory_mb,
  ROUND((MAX(gm.gpu_memory) - MIN(gm.gpu_memory)) / 1024.0 / 1024.0, 2) as memory_change_mb
FROM android_gpu_memory_per_process gm
JOIN process p ON gm.upid = p.upid
WHERE (p.name GLOB '${package}*' OR '${package}' = '')
  AND (${start_ts} IS NULL OR gm.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR gm.ts < ${end_ts})
GROUP BY p.name
ORDER BY max_gpu_memory_mb DESC
LIMIT 15
