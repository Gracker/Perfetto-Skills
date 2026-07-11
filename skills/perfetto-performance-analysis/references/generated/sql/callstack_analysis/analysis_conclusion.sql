-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
