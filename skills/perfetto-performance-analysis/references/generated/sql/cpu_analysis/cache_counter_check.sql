-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  CASE WHEN EXISTS (
    SELECT 1
    FROM counter_track
    WHERE LOWER(name) LIKE '%cache%'
      AND (LOWER(name) LIKE '%miss%' OR LOWER(name) LIKE '%mpki%')
  ) THEN 1 ELSE 0 END as has_cache_counter
