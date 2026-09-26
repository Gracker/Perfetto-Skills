-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 7fe3eb2595b5f8920c8da24ca631b91a13f1e04ac0fe3dda1f3efae096b3319b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  process_name,
  gc_type,
  is_mark_compact,
  COUNT(*) AS gc_count,
  ROUND(SUM(gc_dur) / 1e6, 2) AS total_gc_dur_ms,
  ROUND(AVG(gc_dur) / 1e6, 2) AS avg_gc_dur_ms,
  ROUND(MAX(gc_dur) / 1e6, 2) AS max_gc_dur_ms,
  ROUND(SUM(reclaimed_mb), 2) AS total_reclaimed_mb,
  ROUND(AVG(reclaimed_mb), 2) AS avg_reclaimed_mb
FROM android_garbage_collection_events
WHERE CASE WHEN '${package}' != ''
           THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
           ELSE 1 END
  AND gc_dur / 1e6 >= COALESCE(${min_gc_dur_ms|5}, 5)
  AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
  AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
GROUP BY process_name, gc_type, is_mark_compact
ORDER BY total_gc_dur_ms DESC
