-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH
frame_modules AS (
  SELECT
    ps.callsite_id,
    COALESCE(spm.name, 'unknown') as module_name,
    CASE
      WHEN spm.name LIKE '%.so' THEN 'native'
      WHEN spm.name LIKE '%.dex' OR spm.name LIKE '%.apk' THEN 'java'
      WHEN spm.name LIKE '%kernel%' OR spm.name LIKE '%vmlinux%' THEN 'kernel'
      ELSE 'other'
    END as module_type
  FROM perf_sample ps
  LEFT JOIN stack_profile_callsite spc ON ps.callsite_id = spc.id
  LEFT JOIN stack_profile_frame spf ON spc.frame_id = spf.id
  LEFT JOIN stack_profile_mapping spm ON spf.mapping_id = spm.id
)
SELECT
  module_name,
  module_type,
  COUNT(*) as sample_count,
  ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM perf_sample), 0), 2) as percentage
FROM frame_modules
GROUP BY module_name, module_type
ORDER BY sample_count DESC
LIMIT 15
