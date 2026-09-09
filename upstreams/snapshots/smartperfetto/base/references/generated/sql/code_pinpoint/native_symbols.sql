-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/code_pinpoint.skill.yaml
-- Source SHA-256: c2560c8a63a870cc090ef0176632c2c572fd52bb4301adaa16342cbb651204ce
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH
scoped_samples AS (
  SELECT ps.callsite_id
  FROM perf_sample ps
  JOIN thread t ON t.utid = ps.utid
  JOIN process p ON p.upid = t.upid
  WHERE (
    '${package}' = ''
    OR p.name = '${package}'
    OR (
      '${package}' != ''
      AND SUBSTR(p.name, 1, LENGTH('${package}') + 1) = '${package}' || ':'
    )
  )
    AND (${start_ts} IS NULL OR ps.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ps.ts <= ${end_ts})
),
resolved_samples AS (
  SELECT
    COALESCE(
      (
        SELECT symbol.name
        FROM stack_profile_symbol symbol
        WHERE symbol.symbol_set_id = frame.symbol_set_id
        ORDER BY symbol.inlined DESC, symbol.id
        LIMIT 1
      ),
      frame.deobfuscated_name,
      frame.name
    ) AS function_name,
    mapping.name AS module_name,
    mapping.build_id AS build_id
  FROM scoped_samples sample
  JOIN stack_profile_callsite callsite ON callsite.id = sample.callsite_id
  JOIN stack_profile_frame frame ON frame.id = callsite.frame_id
  JOIN stack_profile_mapping mapping ON mapping.id = frame.mapping
)
SELECT
  function_name,
  module_name,
  build_id,
  COUNT(*) AS sample_count
FROM resolved_samples
WHERE function_name IS NOT NULL
  AND function_name != ''
  AND module_name IS NOT NULL
  AND module_name != ''
GROUP BY function_name, module_name, build_id
ORDER BY sample_count DESC, function_name, module_name, build_id
LIMIT 30;
