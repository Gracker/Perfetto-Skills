-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: 2af64b097eb6ef55456b39938820e6bc4ae09d23ff1331109751e7499b6603f3
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  CASE WHEN EXISTS (
    SELECT 1
    FROM counter_track
    WHERE LOWER(name) LIKE '%cache%'
      AND (LOWER(name) LIKE '%miss%' OR LOWER(name) LIKE '%mpki%')
  ) THEN 1 ELSE 0 END as has_cache_counter
