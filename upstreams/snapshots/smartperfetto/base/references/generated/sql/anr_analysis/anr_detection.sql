-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 5b3df6636aa845fd7e5a72bd067025fd3ae618c026113c370b10c97284bdf3b2

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
