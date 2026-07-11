-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 94563f8717669e993b92723f09bb10688c8a9ac9d9c9caf91391ddf4ecf14639
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM android_garbage_collection_events
    WHERE CASE WHEN '${package}' != ''
               THEN process_name GLOB '*${package}*'
               ELSE 1 END
      AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
      AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM android_garbage_collection_events
    WHERE CASE WHEN '${package}' != ''
               THEN process_name GLOB '*${package}*'
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
