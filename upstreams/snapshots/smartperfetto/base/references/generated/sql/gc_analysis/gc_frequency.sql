-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 7fe3eb2595b5f8920c8da24ca631b91a13f1e04ac0fe3dda1f3efae096b3319b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  CAST(gc_ts / 1e9 AS INTEGER) AS time_sec,
  COUNT(*) AS gc_count,
  ROUND(SUM(gc_dur) / 1e6, 2) AS gc_dur_ms,
  ROUND(SUM(reclaimed_mb), 2) AS reclaimed_mb
FROM android_garbage_collection_events
WHERE CASE WHEN '${package}' != ''
           THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
           ELSE 1 END
  AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
GROUP BY time_sec
HAVING gc_count > 0
ORDER BY time_sec
