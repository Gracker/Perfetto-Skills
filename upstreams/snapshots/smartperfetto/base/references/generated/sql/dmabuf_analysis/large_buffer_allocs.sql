-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 15c7918ef202638b9eb23a3c1e4d1b3f3ab1e091ae7c43784b1858386b89227d
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  printf('%d', ts) AS ts,
  process_name,
  thread_name,
  ROUND(buf_size / 1024.0 / 1024.0, 2) AS size_mb,
  inode
FROM android_dmabuf_allocs
WHERE buf_size / 1024.0 / 1024.0 >= COALESCE(${min_size_mb|1}, 1)
  AND (CASE WHEN '${package}' != ''
            THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
            ELSE 1 END)
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY buf_size DESC
LIMIT 50
