-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

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
