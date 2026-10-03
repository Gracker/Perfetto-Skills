-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 886c11c88b8de59f7a759bb5510cc207277be4fee7d37149ed00f9c1c29c96f9

SELECT
  COUNT(*) as total_anr_count,
  COUNT(DISTINCT process_name) as affected_process_count,
  MIN(ts) as first_anr_ts,
  MAX(ts) as last_anr_ts,
  ROUND((MAX(ts) - MIN(ts)) / 1e9, 2) as anr_span_seconds
FROM android_anrs
WHERE (
    ('${process_name}' <> '' AND (process_name = '${process_name}' OR process_name GLOB '${process_name}:*'))
    OR ('${package}' <> '' AND (process_name = '${package}' OR process_name GLOB '${package}:*'))
    OR ('${process_name}' = '' AND '${package}' = '')
  )
  AND (anr_type = '${anr_type}' OR '${anr_type}' = '')
