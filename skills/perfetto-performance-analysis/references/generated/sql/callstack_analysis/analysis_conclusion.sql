-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: 32723ee660e8cc822dc7b98136a23b15ba55fc88f77942c0ee0b658a654680f1
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH
sample_info AS (
  SELECT * FROM (${sample_stats})
),
top_func AS (
  SELECT
    function_name,
    percentage
  FROM (${hot_functions})
  LIMIT 3
),
top_module AS (
  SELECT
    module_type,
    SUM(percentage) as total_pct
  FROM (${module_distribution})
  GROUP BY module_type
  ORDER BY total_pct DESC
  LIMIT 1
)
SELECT
  (SELECT total_samples FROM sample_info) as total_samples,
  (SELECT duration_sec FROM sample_info) as duration_sec,
  (SELECT GROUP_CONCAT(function_name || ' (' || percentage || '%)' , ', ') FROM top_func) as top_hotspots,
  (SELECT module_type || ' (' || ROUND(total_pct, 1) || '%)' FROM top_module) as dominant_module_type,
  CASE
    WHEN (SELECT total_pct FROM top_module) > 50 THEN
      CASE (SELECT module_type FROM top_module)
        WHEN 'kernel' THEN '系统调用开销较大，建议检查 IO/锁竞争'
        WHEN 'native' THEN 'Native 代码占比高，关注 JNI 调用和 Native 库'
        WHEN 'java' THEN 'Java 层代码占主导，建议优化业务逻辑'
        ELSE '需要进一步分析'
      END
    ELSE '采样分布较均匀，无明显热点模块'
  END as suggestion
