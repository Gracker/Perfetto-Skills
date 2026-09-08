-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: fc08d54c591a45a1488f7d1064504f08f7d3d2fa95b42eec2a1c6da725ec5f08
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH RECURSIVE
-- 展开调用栈
callsite_tree AS (
  SELECT
    id,
    parent_id,
    frame_id,
    depth
  FROM stack_profile_callsite
),
-- 统计每个栈帧的采样数
frame_samples AS (
  SELECT
    ct.frame_id,
    COUNT(*) as sample_count
  FROM perf_sample ps
  JOIN callsite_tree ct ON ps.callsite_id = ct.id
  GROUP BY ct.frame_id
),
-- 关联符号信息
frame_symbols AS (
  SELECT
    fs.frame_id,
    fs.sample_count,
    COALESCE(
      (
        SELECT sps.name
        FROM stack_profile_symbol sps
        WHERE sps.symbol_set_id = spf.symbol_set_id
        ORDER BY sps.inlined DESC, sps.id
        LIMIT 1
      ),
      spf.deobfuscated_name,
      spf.name,
      'unknown'
    ) as function_name,
    COALESCE(spm.name, 'unknown') as module_name
  FROM frame_samples fs
  LEFT JOIN stack_profile_frame spf ON fs.frame_id = spf.id
  LEFT JOIN stack_profile_mapping spm ON spf.mapping = spm.id
)
SELECT
  function_name,
  module_name,
  sample_count,
  ROUND(sample_count * 100.0 / NULLIF((SELECT total_samples FROM (${sample_stats})), 0), 2) as percentage
FROM frame_symbols
WHERE sample_count >= ${min_samples}
ORDER BY sample_count DESC
LIMIT 20
