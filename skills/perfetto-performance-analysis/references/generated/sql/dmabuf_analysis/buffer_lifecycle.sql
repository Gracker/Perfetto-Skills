-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 15c7918ef202638b9eb23a3c1e4d1b3f3ab1e091ae7c43784b1858386b89227d
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH allocs AS (
  SELECT
    inode,
    ts AS alloc_ts,
    buf_size,
    process_name
  FROM android_dmabuf_allocs
  WHERE buf_size > 0
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
frees AS (
  SELECT
    inode,
    ts AS free_ts
  FROM android_dmabuf_allocs
  WHERE buf_size < 0
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
lifecycles AS (
  SELECT
    a.process_name,
    a.buf_size,
    MIN(f.free_ts) AS free_ts,
    a.alloc_ts,
    MIN(f.free_ts) - a.alloc_ts AS lifetime
  FROM allocs a
  LEFT JOIN frees f ON a.inode = f.inode AND f.free_ts > a.alloc_ts
  GROUP BY a.inode, a.alloc_ts
)
SELECT
  process_name,
  COUNT(*) AS buffer_count,
  COUNT(free_ts) AS freed_count,
  COUNT(*) - COUNT(free_ts) AS not_freed_count,
  ROUND(AVG(lifetime) / 1e9, 2) AS avg_lifetime_sec,
  ROUND(MAX(lifetime) / 1e9, 2) AS max_lifetime_sec
FROM lifecycles
WHERE (CASE WHEN '${package}' != ''
            THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
            ELSE 1 END)
GROUP BY process_name
ORDER BY not_freed_count DESC
