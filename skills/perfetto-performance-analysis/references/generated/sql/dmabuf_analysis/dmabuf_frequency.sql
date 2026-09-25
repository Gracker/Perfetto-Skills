-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 15c7918ef202638b9eb23a3c1e4d1b3f3ab1e091ae7c43784b1858386b89227d
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  CAST(ts / 1000000000 AS INTEGER) AS time_sec,
  COUNT(CASE WHEN buf_size > 0 THEN 1 END) AS alloc_count,
  COUNT(CASE WHEN buf_size < 0 THEN 1 END) AS free_count,
  ROUND(SUM(CASE WHEN buf_size > 0 THEN buf_size ELSE 0 END) / 1024.0 / 1024.0, 2) AS alloc_mb,
  ROUND(SUM(CASE WHEN buf_size < 0 THEN -buf_size ELSE 0 END) / 1024.0 / 1024.0, 2) AS free_mb
FROM android_dmabuf_allocs
WHERE (CASE WHEN '${package}' != ''
            THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
            ELSE 1 END)
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY time_sec
ORDER BY time_sec
