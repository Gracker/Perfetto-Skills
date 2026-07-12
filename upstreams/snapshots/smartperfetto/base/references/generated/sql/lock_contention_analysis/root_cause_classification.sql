-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lock_contention_analysis.skill.yaml
-- Source SHA-256: 3ab24e4626566ee3a7eedcbdc46815378b714668c8dd6ee54ddd6d6c2f1b1b56
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH
-- 主线程锁竞争统计
main_thread_stats AS (
  SELECT
    COUNT(*) AS main_contention_count,
    COALESCE(SUM(dur) / 1e6, 0) AS main_total_blocked_ms,
    COALESCE(MAX(dur) / 1e6, 0) AS main_max_blocked_ms
  FROM android_monitor_contention
  WHERE is_blocked_thread_main = 1
    AND CASE WHEN '${process_name}' != ''
             THEN process_name GLOB '*${process_name}*'
             ELSE 1 END
    AND dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
-- 热点锁统计（单锁最大竞争次数和等待线程数）
hotspot_stats AS (
  SELECT
    MAX(cnt) AS max_lock_contention_count,
    MAX(unique_waiters) AS max_unique_waiters
  FROM (
    SELECT
      short_blocking_method,
      COUNT(*) AS cnt,
      COUNT(DISTINCT blocked_utid) AS unique_waiters
    FROM android_monitor_contention
    WHERE CASE WHEN '${process_name}' != ''
               THEN process_name GLOB '*${process_name}*'
               ELSE 1 END
      AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
    GROUP BY short_blocking_method
  )
),
-- 锁链统计
chain_stats AS (
  SELECT
    COUNT(*) AS chain_node_count
  FROM android_monitor_contention_chain c
  WHERE (c.parent_id IS NOT NULL AND c.child_id IS NOT NULL)
    AND CASE WHEN '${process_name}' != ''
             THEN c.process_name GLOB '*${process_name}*'
             ELSE 1 END
    AND (${start_ts} IS NULL OR c.ts + c.dur > ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
-- Binder 关联统计
binder_stats AS (
  SELECT
    COUNT(*) AS binder_contention_count,
    COALESCE(SUM(dur) / 1e6, 0) AS binder_contention_ms
  FROM android_monitor_contention
  WHERE binder_reply_tid IS NOT NULL
    AND CASE WHEN '${process_name}' != ''
             THEN process_name GLOB '*${process_name}*'
             ELSE 1 END
    AND dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
-- 总体统计
overall_stats AS (
  SELECT
    COUNT(*) AS total_count,
    COALESCE(SUM(dur) / 1e6, 0) AS total_blocked_ms
  FROM android_monitor_contention
  WHERE CASE WHEN '${process_name}' != ''
             THEN process_name GLOB '*${process_name}*'
             ELSE 1 END
    AND dur / 1e6 >= COALESCE(${min_duration_ms|10}, 10)
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
diagnoses AS (
  -- LOCK_MAIN_THREAD: 主线程被严重锁阻塞
  SELECT
    'LOCK_MAIN_THREAD' AS category,
    'critical' AS severity,
    '主线程被锁阻塞 ' || (SELECT main_contention_count FROM main_thread_stats)
      || ' 次，总阻塞 ' || ROUND((SELECT main_total_blocked_ms FROM main_thread_stats), 1)
      || 'ms，最长单次 ' || ROUND((SELECT main_max_blocked_ms FROM main_thread_stats), 1) || 'ms' AS description,
    '主线程竞争次数: ' || (SELECT main_contention_count FROM main_thread_stats)
      || ', 总阻塞: ' || ROUND((SELECT main_total_blocked_ms FROM main_thread_stats), 1)
      || 'ms, 最大单次: ' || ROUND((SELECT main_max_blocked_ms FROM main_thread_stats), 1) || 'ms' AS evidence
  WHERE (SELECT main_contention_count FROM main_thread_stats) > 5
    AND (SELECT main_total_blocked_ms FROM main_thread_stats) > 100
  UNION ALL
  -- LOCK_HOTSPOT: 单锁高频竞争
  SELECT
    'LOCK_HOTSPOT' AS category,
    'warning' AS severity,
    '单锁最大竞争 ' || (SELECT max_lock_contention_count FROM hotspot_stats)
      || ' 次，涉及 ' || (SELECT max_unique_waiters FROM hotspot_stats) || ' 个不同线程' AS description,
    '最大单锁竞争次数: ' || (SELECT max_lock_contention_count FROM hotspot_stats)
      || ', 最大不同等待线程数: ' || (SELECT max_unique_waiters FROM hotspot_stats) AS evidence
  WHERE (SELECT max_lock_contention_count FROM hotspot_stats) > 20
    OR (SELECT max_unique_waiters FROM hotspot_stats) > 5
  UNION ALL
  -- LOCK_CHAIN: 检测到锁传递链
  SELECT
    'LOCK_CHAIN' AS category,
    'warning' AS severity,
    '检测到 ' || (SELECT chain_node_count FROM chain_stats) || ' 个锁链中间节点，存在锁传递风险' AS description,
    '锁链中间节点数: ' || (SELECT chain_node_count FROM chain_stats) AS evidence
  WHERE (SELECT chain_node_count FROM chain_stats) > 0
  UNION ALL
  -- LOCK_BINDER: Binder 事务期间锁竞争
  SELECT
    'LOCK_BINDER' AS category,
    'warning' AS severity,
    'Binder 事务期间发生 ' || (SELECT binder_contention_count FROM binder_stats)
      || ' 次锁竞争，累计 ' || ROUND((SELECT binder_contention_ms FROM binder_stats), 1) || 'ms' AS description,
    'Binder 期间竞争次数: ' || (SELECT binder_contention_count FROM binder_stats)
      || ', 累计: ' || ROUND((SELECT binder_contention_ms FROM binder_stats), 1) || 'ms' AS evidence
  WHERE (SELECT binder_contention_count FROM binder_stats) > 3
    AND (SELECT binder_contention_ms FROM binder_stats) > 50
  UNION ALL
  -- LOCK_NORMAL: 锁竞争在正常范围
  SELECT
    'LOCK_NORMAL' AS category,
    'info' AS severity,
    '共 ' || (SELECT total_count FROM overall_stats) || ' 次锁竞争，总阻塞 '
      || ROUND((SELECT total_blocked_ms FROM overall_stats), 1) || 'ms，在正常范围内' AS description,
    '总竞争次数: ' || (SELECT total_count FROM overall_stats)
      || ', 总阻塞: ' || ROUND((SELECT total_blocked_ms FROM overall_stats), 1) || 'ms' AS evidence
  WHERE (SELECT main_contention_count FROM main_thread_stats) <= 5
    AND COALESCE((SELECT max_lock_contention_count FROM hotspot_stats), 0) <= 20
    AND COALESCE((SELECT max_unique_waiters FROM hotspot_stats), 0) <= 5
    AND (SELECT chain_node_count FROM chain_stats) = 0
    AND ((SELECT binder_contention_count FROM binder_stats) <= 3 OR (SELECT binder_contention_ms FROM binder_stats) <= 50)
)
SELECT category, severity, description, evidence
FROM diagnoses
ORDER BY
  CASE severity
    WHEN 'critical' THEN 1
    WHEN 'warning' THEN 2
    WHEN 'info' THEN 3
    ELSE 4
  END
