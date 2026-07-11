-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: b3ab914b724ad69264ba04c73c6cb054a3567de1ffde3e53768eb349ac5d3afe
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  CASE WHEN EXISTS (
    SELECT 1
    FROM counter_track
    WHERE LOWER(name) LIKE '%cache%'
      AND (LOWER(name) LIKE '%miss%' OR LOWER(name) LIKE '%mpki%')
  ) THEN 1 ELSE 0 END as has_cache_counter
