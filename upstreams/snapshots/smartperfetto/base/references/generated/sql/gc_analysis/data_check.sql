-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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
