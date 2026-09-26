-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 380a21355baca5f8e2d2d740174e6f6897b0150f4d792c53f3b0d42de71a0f1b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM android_lmk_events
    WHERE CASE WHEN '${package}' != ''
               THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
               ELSE 1 END
      AND (${start_ts} IS NULL OR ts > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_data,
  CASE WHEN EXISTS (
    SELECT 1 FROM android_lmk_events
    WHERE oom_score_adj <= 200
      AND CASE WHEN '${package}' != ''
               THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
               ELSE 1 END
      AND (${start_ts} IS NULL OR ts > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
    LIMIT 1
  ) THEN 1 ELSE 0 END as has_high_priority_kills,
  CASE WHEN EXISTS (
    SELECT 1 FROM counter_track WHERE name = 'mem.free' LIMIT 1
  ) THEN 1 ELSE 0 END as has_memory_counters
