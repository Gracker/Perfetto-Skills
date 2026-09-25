-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 15c7918ef202638b9eb23a3c1e4d1b3f3ab1e091ae7c43784b1858386b89227d
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH latest_values AS (
  SELECT
    upid,
    process_name,
    value AS latest_value,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY ts DESC) AS rn
  FROM android_memory_cumulative_dmabuf
  WHERE (CASE WHEN '${package}' != ''
              THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
              ELSE 1 END)
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
peak_values AS (
  SELECT
    upid,
    MAX(value) AS peak_value
  FROM android_memory_cumulative_dmabuf
  WHERE (CASE WHEN '${package}' != ''
              THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
              ELSE 1 END)
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  GROUP BY upid
)
SELECT
  l.process_name,
  ROUND(l.latest_value / 1024.0 / 1024.0, 2) AS current_mb,
  ROUND(p.peak_value / 1024.0 / 1024.0, 2) AS peak_mb
FROM latest_values l
JOIN peak_values p ON l.upid = p.upid
WHERE l.rn = 1
ORDER BY current_mb DESC
