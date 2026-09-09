-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: bbe145b95ab30fa9dd885a45be7807284558b2acb6ae49984bc6a0c137982397
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  CASE WHEN EXISTS (
    SELECT 1
    FROM counter_track
    WHERE LOWER(name) LIKE '%cache%'
      AND (LOWER(name) LIKE '%miss%' OR LOWER(name) LIKE '%mpki%')
  ) THEN 1 ELSE 0 END as has_cache_counter
