-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
    COALESCE(sps.name, 'unknown') as function_name,
    COALESCE(spm.name, 'unknown') as module_name
  FROM frame_samples fs
  LEFT JOIN stack_profile_frame spf ON fs.frame_id = spf.id
  LEFT JOIN stack_profile_symbol sps ON spf.symbol_id = sps.id
  LEFT JOIN stack_profile_mapping spm ON spf.mapping_id = spm.id
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
