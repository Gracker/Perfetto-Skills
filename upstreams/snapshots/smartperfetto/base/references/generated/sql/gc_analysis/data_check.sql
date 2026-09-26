-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 7fe3eb2595b5f8920c8da24ca631b91a13f1e04ac0fe3dda1f3efae096b3319b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM android_garbage_collection_events
    WHERE CASE WHEN '${package}' != ''
               THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
               ELSE 1 END
      AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
      AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM android_garbage_collection_events
    WHERE CASE WHEN '${package}' != ''
               THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
               ELSE 1 END
      AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
      AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
      AND gc_dur / 1e6 >= COALESCE(${min_gc_dur_ms|5}, 5) * 2
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_long_gc,
  CASE WHEN EXISTS (
    SELECT 1 FROM _android_garbage_collection_process_stats
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_process_stats
