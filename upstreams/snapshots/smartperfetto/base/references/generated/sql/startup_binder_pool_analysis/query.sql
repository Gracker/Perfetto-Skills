-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_binder_pool_analysis.skill.yaml
-- Source SHA-256: 10d4853d77be31976d5238ca1b58dbda245f3e8372eca058a69fbd8303127584
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH binder_threads AS (
  SELECT t.utid, t.name as thread_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
    AND t.name GLOB 'Binder:*'
),
pool_stats AS (
  SELECT
    COUNT(DISTINCT bt.utid) as pool_size,
    ROUND(SUM(CASE WHEN ts.state = 'Running' THEN
      (MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts}))
    ELSE 0 END) / 1e6, 2) as total_running_ms,
    ROUND(SUM(CASE WHEN ts.state = 'S'
      AND (ts.blocked_function GLOB '*binder_wait_for_work*'
           OR ts.blocked_function GLOB '*binder_thread_read*') THEN
      (MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts}))
    ELSE 0 END) / 1e6, 2) as total_idle_ms,
    ROUND(SUM(CASE WHEN ts.state = 'S'
      AND ts.blocked_function IS NOT NULL
      AND ts.blocked_function NOT GLOB '*binder_wait_for_work*'
      AND ts.blocked_function NOT GLOB '*binder_thread_read*' THEN
      (MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts}))
    ELSE 0 END) / 1e6, 2) as total_blocked_ms
  FROM binder_threads bt
  JOIN thread_state ts ON ts.utid = bt.utid
  WHERE ts.ts < ${end_ts} AND ts.ts + ts.dur > ${start_ts}
)
SELECT '线程池大小' as metric,
  pool_size || ' 个 Binder 线程' as value,
  CASE WHEN pool_size = 0 THEN '⚠️ 未检测到 Binder 线程'
       WHEN pool_size < 3 THEN '线程池较小'
       ELSE '正常' END as assessment
FROM pool_stats
UNION ALL
SELECT '线程池利用率' as metric,
  ROUND(100.0 * total_running_ms / NULLIF(total_running_ms + total_idle_ms, 0), 1) || '%' ||
  ' (Running ' || total_running_ms || 'ms / Idle ' || total_idle_ms || 'ms)' as value,
  CASE
    WHEN total_running_ms / NULLIF(total_running_ms + total_idle_ms, 0) > 0.8 THEN '⚠️ 利用率过高，可能存在排队'
    WHEN total_running_ms / NULLIF(total_running_ms + total_idle_ms, 0) > 0.5 THEN '中等利用率'
    ELSE '利用率正常'
  END as assessment
FROM pool_stats
UNION ALL
SELECT 'Binder 线程被阻塞' as metric,
  total_blocked_ms || ' ms (非 binder_wait 的 S 状态)' as value,
  CASE
    WHEN total_blocked_ms > 50 THEN '⚠️ Binder 线程自身被阻塞（锁竞争/IO），影响服务响应'
    WHEN total_blocked_ms > 10 THEN '有一定阻塞'
    ELSE '正常'
  END as assessment
FROM pool_stats
