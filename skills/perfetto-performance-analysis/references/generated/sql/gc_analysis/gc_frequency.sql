-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 94563f8717669e993b92723f09bb10688c8a9ac9d9c9caf91391ddf4ecf14639
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  CAST(gc_ts / 1e9 AS INTEGER) AS time_sec,
  COUNT(*) AS gc_count,
  ROUND(SUM(gc_dur) / 1e6, 2) AS gc_dur_ms,
  ROUND(SUM(reclaimed_mb), 2) AS reclaimed_mb
FROM android_garbage_collection_events
WHERE CASE WHEN '${package}' != ''
           THEN process_name GLOB '*${package}*'
           ELSE 1 END
  AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
GROUP BY time_sec
HAVING gc_count > 0
ORDER BY time_sec
