-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_analysis.skill.yaml
-- Source SHA-256: 9a20a24042252892aabc8ff420a5f4777953bd6c041b00285dc3402f3cf6182e
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
