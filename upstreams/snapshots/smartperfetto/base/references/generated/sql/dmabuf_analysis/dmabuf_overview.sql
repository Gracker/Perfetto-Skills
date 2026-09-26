-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 15c7918ef202638b9eb23a3c1e4d1b3f3ab1e091ae7c43784b1858386b89227d
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  process_name,
  COUNT(*) AS alloc_count,
  ROUND(SUM(CASE WHEN buf_size > 0 THEN buf_size ELSE 0 END) / 1024.0 / 1024.0, 2) AS total_alloc_mb,
  ROUND(SUM(CASE WHEN buf_size < 0 THEN -buf_size ELSE 0 END) / 1024.0 / 1024.0, 2) AS total_free_mb,
  ROUND(SUM(buf_size) / 1024.0 / 1024.0, 2) AS net_alloc_mb,
  ROUND(MAX(buf_size) / 1024.0 / 1024.0, 2) AS max_single_alloc_mb
FROM android_dmabuf_allocs
WHERE (CASE WHEN '${package}' != ''
            THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
            ELSE 1 END)
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY process_name
ORDER BY total_alloc_mb DESC
