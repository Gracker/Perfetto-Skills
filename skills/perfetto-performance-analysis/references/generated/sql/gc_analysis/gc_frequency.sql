-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
