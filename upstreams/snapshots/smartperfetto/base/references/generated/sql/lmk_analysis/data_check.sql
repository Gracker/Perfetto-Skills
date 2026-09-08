-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 4847d51840b9975df3dd72b632137f8edd23b91bf4ba70da3c27f6d86393eda0
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
