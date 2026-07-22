-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: d1aa0860a3371aeb91af3a7e07f864dba1a417a0e9e9d1e3d1387ef0bb02aec2
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM android_lmk_events
    WHERE CASE WHEN '${package}' != ''
               THEN process_name GLOB '*${package}*'
               ELSE 1 END
      AND (${start_ts} IS NULL OR ts > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM android_lmk_events
    WHERE oom_score_adj <= 200
      AND CASE WHEN '${package}' != ''
               THEN process_name GLOB '*${package}*'
               ELSE 1 END
      AND (${start_ts} IS NULL OR ts > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_high_priority_kills,
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE name = 'mem.free' LIMIT 1
  ) THEN 1 ELSE 0 END as has_memory_counters
