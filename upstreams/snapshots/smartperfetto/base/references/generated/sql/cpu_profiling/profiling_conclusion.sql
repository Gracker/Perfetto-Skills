-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

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
big_core_usage AS (
  SELECT AVG(big_core_pct) as avg_big_core_pct FROM (${core_distribution})
)
SELECT
  (SELECT thread_name FROM top_thread) as top_cpu_thread,
  (SELECT ROUND(cpu_time_ms, 1) FROM top_thread) as top_thread_cpu_ms,
  (SELECT ROUND(overall_avg_latency, 2) FROM latency_stats) as avg_sched_latency_ms,
  (SELECT ROUND(worst_latency, 1) FROM latency_stats) as worst_sched_latency_ms,
  (SELECT ROUND(avg_big_core_pct, 1) FROM big_core_usage) as avg_big_core_usage_pct,
  CASE
    WHEN (SELECT worst_latency FROM latency_stats) > 50 THEN 'high_latency'
    WHEN (SELECT worst_latency FROM latency_stats) > 20 THEN 'moderate_latency'
    ELSE 'normal'
  END as latency_severity,
  CASE
    WHEN (SELECT overall_avg_latency FROM latency_stats) > 10
      THEN '调度延迟偏高，可能存在 CPU 竞争或优先级问题'
    WHEN (SELECT avg_big_core_pct FROM big_core_usage) < 30
      THEN '大核利用率低，关键线程可能未正确绑核'
    WHEN (SELECT avg_big_core_pct FROM big_core_usage) > 80
      THEN '过度使用大核，考虑部分任务迁移到小核以节省功耗'
    ELSE 'CPU 调度和使用效率良好'
  END as suggestion
