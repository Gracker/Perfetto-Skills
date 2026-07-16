-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: 32723ee660e8cc822dc7b98136a23b15ba55fc88f77942c0ee0b658a654680f1
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH RECURSIVE
-- 获取 Top 5 热点函数的 frame_id
top_frames AS (
  SELECT DISTINCT
    spf.id as frame_id,
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
    ) as function_name
  FROM stack_profile_frame spf
  WHERE COALESCE(
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
  ) IN (
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
    ) as caller_name
  FROM caller_chain cc
  JOIN stack_profile_callsite spc ON cc.parent_id = spc.id
  LEFT JOIN stack_profile_frame spf ON spc.frame_id = spf.id
)
SELECT
  hot_function,
  depth as call_depth,
  caller_name,
  COUNT(*) as occurrence_count
FROM caller_stats
GROUP BY hot_function, depth, caller_name
ORDER BY hot_function, depth, occurrence_count DESC
