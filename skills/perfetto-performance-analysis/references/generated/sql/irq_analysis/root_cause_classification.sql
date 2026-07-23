-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH
irq_totals AS (
  SELECT
    COUNT(*) as total_count,
    SUM(dur) / 1e6 as total_dur_ms,
    SUM(CASE WHEN is_soft_irq = 0 THEN 1 ELSE 0 END) as hard_count,
    SUM(CASE WHEN is_soft_irq = 1 THEN 1 ELSE 0 END) as soft_count
  FROM linux_irqs
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
long_hard AS (
  SELECT COUNT(*) as cnt
  FROM linux_irqs
  WHERE is_soft_irq = 0
    AND dur > ${hard_irq_long_threshold_us|1000} * 1000
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
long_soft AS (
  SELECT COUNT(*) as cnt
  FROM linux_irqs
  WHERE is_soft_irq = 1
    AND dur > ${soft_irq_long_threshold_us|10000} * 1000
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
trace_duration AS (
  SELECT (MAX(ts) - MIN(ts)) / 1e9 as trace_sec
  FROM linux_irqs
)
SELECT
  CASE
    WHEN (SELECT cnt FROM long_hard) > 10 OR (SELECT cnt FROM long_soft) > 10
      THEN 'IRQ_LATENCY'
    WHEN (SELECT total_count FROM irq_totals) / NULLIF((SELECT trace_sec FROM trace_duration), 0) > ${irq_rate_heavy_threshold|10000}
      THEN 'IRQ_HEAVY'
    WHEN (SELECT total_dur_ms FROM irq_totals) / NULLIF((SELECT trace_sec FROM trace_duration), 0) > ${irq_dur_heavy_threshold_ms|50}
      THEN 'IRQ_HEAVY'
    ELSE 'IRQ_NORMAL'
  END as classification,
  (SELECT total_count FROM irq_totals) as total_irq_count,
  ROUND((SELECT total_dur_ms FROM irq_totals), 2) as total_dur_ms,
  (SELECT cnt FROM long_hard) as long_hard_irq_count,
  (SELECT cnt FROM long_soft) as long_soft_irq_count,
  CASE
    WHEN (SELECT cnt FROM long_hard) > 10 OR (SELECT cnt FROM long_soft) > 10
      THEN '存在异常长耗时中断 (硬中断 >' || (SELECT cnt FROM long_hard) || ' 次 >1ms，软中断 ' || (SELECT cnt FROM long_soft) || ' 次 >10ms)，可能影响实时性和调度延迟'
    WHEN (SELECT total_count FROM irq_totals) / NULLIF((SELECT trace_sec FROM trace_duration), 0) > ${irq_rate_heavy_threshold|10000}
      THEN '中断负载较重 (>' || CAST(ROUND((SELECT total_count FROM irq_totals) / NULLIF((SELECT trace_sec FROM trace_duration), 0)) AS INT) || '/秒)，可能影响 CPU 可用时间'
    WHEN (SELECT total_dur_ms FROM irq_totals) / NULLIF((SELECT trace_sec FROM trace_duration), 0) > ${irq_dur_heavy_threshold_ms|50}
      THEN '中断处理耗时较高 (每秒 >' || ROUND((SELECT total_dur_ms FROM irq_totals) / NULLIF((SELECT trace_sec FROM trace_duration), 0), 1) || 'ms)，可能抢占用户态 CPU 时间'
    ELSE '中断负载正常，未检测到异常'
  END as description
