-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  COUNT(*) as total_gc_count,
  SUM(dur) / 1e6 as total_gc_time_ms,
  ROUND(AVG(dur) / 1e6, 2) as avg_gc_time_ms,
  ROUND(MAX(dur) / 1e6, 2) as max_gc_time_ms,
  ROUND(MIN(dur) / 1e6, 2) as min_gc_time_ms,
  -- 主线程 GC 统计
  SUM(CASE WHEN is_main_thread = 1 THEN 1 ELSE 0 END) as main_thread_gc_count,
  SUM(CASE WHEN is_main_thread = 1 THEN dur ELSE 0 END) / 1e6 as main_thread_gc_time_ms,
  -- GC 频率（每秒）
  ROUND(COUNT(*) * 1e9 / (MAX(ts + dur) - MIN(ts)), 2) as gc_per_second,
  -- 评级
  CASE
    WHEN COUNT(*) > ${gc_count_critical|100} THEN '频繁'
    WHEN COUNT(*) > ${gc_count_warning|50} THEN '较多'
    WHEN COUNT(*) > 10 THEN '正常'
    ELSE '良好'
  END as gc_frequency_rating,
  CASE
    WHEN SUM(dur) / 1e6 > ${gc_total_time_critical_ms|2000} THEN '严重'
    WHEN SUM(dur) / 1e6 > 500 THEN '需优化'
    WHEN SUM(dur) / 1e6 > 100 THEN '良好'
    ELSE '优秀'
  END as gc_time_rating
FROM _gc_events
