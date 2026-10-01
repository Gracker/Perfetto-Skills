-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: dce6ebab0c0096f73bc2707459de6af2cb7fefc55f171def6d1303d371c504ae

WITH
top_thread AS (
  SELECT thread_name, cpu_time_ms FROM (${thread_cpu_time}) LIMIT 1
),
latency_stats AS (
  SELECT
    AVG(avg_latency_ms) as overall_avg_latency,
    MAX(max_latency_ms) as worst_latency
  FROM (${scheduling_latency})
),
-- A big-core verdict covers the whole displayed sample, so every sample
-- thread must have run only on classified cores.
big_core_usage AS (
  SELECT
    COUNT(*) as sample_threads,
    SUM(CASE WHEN unknown_core_ms = 0 THEN 1 ELSE 0 END) as classified_threads,
    CASE WHEN MAX(unknown_core_ms) = 0 THEN AVG(big_core_pct) END as avg_big_core_pct
  FROM (${core_distribution})
)
SELECT
  (SELECT thread_name FROM top_thread) as top_cpu_thread,
  (SELECT ROUND(cpu_time_ms, 1) FROM top_thread) as top_thread_cpu_ms,
  (SELECT ROUND(overall_avg_latency, 2) FROM latency_stats) as avg_sched_latency_ms,
  (SELECT ROUND(worst_latency, 1) FROM latency_stats) as worst_sched_latency_ms,
  (SELECT ROUND(avg_big_core_pct, 1) FROM big_core_usage) as avg_big_core_usage_pct,
  (SELECT sample_threads FROM big_core_usage) as big_core_sample_threads,
  (SELECT classified_threads FROM big_core_usage) as classified_sample_threads,
  CASE
    WHEN (SELECT worst_latency FROM latency_stats) > 50 THEN 'high_latency'
    WHEN (SELECT worst_latency FROM latency_stats) > 20 THEN 'moderate_latency'
    ELSE 'normal'
  END as latency_severity,
  CASE
    WHEN (SELECT overall_avg_latency FROM latency_stats) > 10
      THEN '调度延迟偏高，可能存在 CPU 竞争或优先级问题'
    WHEN (SELECT avg_big_core_pct FROM big_core_usage) IS NULL
      THEN '调度延迟未见明显异常；样本线程有运行时间落在未分类 CPU 上（拓扑缺少容量信息），无法评估大小核使用'
    WHEN (SELECT avg_big_core_pct FROM big_core_usage) < 30
      THEN '大核利用率低，关键线程可能未正确绑核'
    WHEN (SELECT avg_big_core_pct FROM big_core_usage) > 80
      THEN '过度使用大核，考虑部分任务迁移到小核以节省功耗'
    ELSE 'CPU 调度和使用效率良好'
  END as suggestion
