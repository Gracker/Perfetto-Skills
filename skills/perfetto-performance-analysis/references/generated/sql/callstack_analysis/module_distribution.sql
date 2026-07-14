-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: 32723ee660e8cc822dc7b98136a23b15ba55fc88f77942c0ee0b658a654680f1
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

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
  LEFT JOIN stack_profile_mapping spm ON spf.mapping = spm.id
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
