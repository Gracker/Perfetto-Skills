-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH RECURSIVE
-- 获取 Top 5 热点函数的 frame_id
top_frames AS (
  SELECT DISTINCT
    spf.id as frame_id,
    sps.name as function_name
  FROM stack_profile_frame spf
  JOIN stack_profile_symbol sps ON spf.symbol_id = sps.id
  WHERE sps.name IN (
    SELECT function_name FROM (${hot_functions}) LIMIT 5
  )
),
-- 找到包含这些热点函数的调用栈
hot_callsites AS (
  SELECT
    spc.id as callsite_id,
    spc.parent_id,
    tf.function_name as hot_function
  FROM stack_profile_callsite spc
  JOIN top_frames tf ON spc.frame_id = tf.frame_id
),
-- 递归向上查找调用者（最多 5 层）
caller_chain AS (
  SELECT
    hc.callsite_id,
    hc.hot_function,
    hc.parent_id,
    1 as depth
  FROM hot_callsites hc

  UNION ALL

  SELECT
    cc.callsite_id,
    cc.hot_function,
    spc.parent_id,
    cc.depth + 1
  FROM caller_chain cc
  JOIN stack_profile_callsite spc ON cc.parent_id = spc.id
  WHERE cc.depth < 5 AND spc.parent_id IS NOT NULL
),
-- 统计调用者
caller_stats AS (
  SELECT
    cc.hot_function,
    cc.depth,
    COALESCE(sps.name, 'unknown') as caller_name
  FROM caller_chain cc
  JOIN stack_profile_callsite spc ON cc.parent_id = spc.id
  LEFT JOIN stack_profile_frame spf ON spc.frame_id = spf.id
  LEFT JOIN stack_profile_symbol sps ON spf.symbol_id = sps.id
)
SELECT
  hot_function,
  depth as call_depth,
  caller_name,
  COUNT(*) as occurrence_count
FROM caller_stats
GROUP BY hot_function, depth, caller_name
ORDER BY hot_function, depth, occurrence_count DESC
