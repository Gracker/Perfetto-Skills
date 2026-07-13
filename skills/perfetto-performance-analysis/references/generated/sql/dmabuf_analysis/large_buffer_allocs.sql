-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 82544957bb27c764d3304e2acc9a3306fa7fab10dc9b095bcfe0cae0798b53f6
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

SELECT
  printf('%d', ts) AS ts,
  process_name,
  thread_name,
  ROUND(buf_size / 1024.0 / 1024.0, 2) AS size_mb,
  inode
FROM android_dmabuf_allocs
WHERE buf_size / 1024.0 / 1024.0 >= COALESCE(${min_size_mb|1}, 1)
  AND (CASE WHEN '${package}' != ''
            THEN process_name GLOB '*${package}*'
            ELSE 1 END)
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY buf_size DESC
LIMIT 50
