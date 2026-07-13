-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 82544957bb27c764d3304e2acc9a3306fa7fab10dc9b095bcfe0cae0798b53f6
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  process_name,
  thread_name,
  COUNT(*) AS alloc_count,
  ROUND(SUM(CASE WHEN buf_size > 0 THEN buf_size ELSE 0 END) / 1024.0 / 1024.0, 2) AS total_alloc_mb
FROM android_dmabuf_allocs
WHERE buf_size > 0
  AND (CASE WHEN '${package}' != ''
            THEN process_name GLOB '*${package}*'
            ELSE 1 END)
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY process_name, thread_name
ORDER BY total_alloc_mb DESC
LIMIT 30
