-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 82544957bb27c764d3304e2acc9a3306fa7fab10dc9b095bcfe0cae0798b53f6
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH latest_values AS (
  SELECT
    upid,
    process_name,
    value AS latest_value,
    ROW_NUMBER() OVER (PARTITION BY upid ORDER BY ts DESC) AS rn
  FROM android_memory_cumulative_dmabuf
  WHERE (CASE WHEN '${package}' != ''
              THEN process_name GLOB '*${package}*'
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
              THEN process_name GLOB '*${package}*'
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
