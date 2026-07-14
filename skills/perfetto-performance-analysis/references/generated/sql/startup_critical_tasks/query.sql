-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_critical_tasks.skill.yaml
-- Source SHA-256: 8d9ffc04a4543994c80e63aba04812d897f68580cb39396c9600aafb01cf51dc
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

-- Step 1: 识别目标进程的所有线程并自动分配角色
WITH process_threads AS (
  SELECT
    t.utid,
    t.tid,
    t.name as thread_name,
    p.pid,
    CASE
      WHEN t.tid = p.pid THEN 'main'
      WHEN t.name = 'RenderThread' THEN 'render'
      WHEN t.name GLOB '*HeapTaskDaemon*' THEN 'gc'
      WHEN t.name GLOB '*FinalizerDaemon*' THEN 'gc'
      WHEN t.name GLOB '*ReferenceQueueDaemon*' THEN 'gc'
      WHEN t.name GLOB 'Jit thread pool*' THEN 'jit'
      WHEN t.name GLOB '*Profile Saver*' THEN 'jit'
      WHEN t.name GLOB 'Binder:*' THEN 'binder'
      WHEN t.name GLOB '*AsyncTask*' OR t.name GLOB 'pool-*-thread-*' THEN 'worker'
      WHEN t.name GLOB '*DefaultDispatcher*' OR t.name GLOB '*Dispatchers.Default*' THEN 'worker'
      WHEN t.name GLOB '*Executor*' OR t.name GLOB '*Worker*' THEN 'worker'
      WHEN t.name GLOB 'OkHttp*' THEN 'worker'
      WHEN t.name GLOB 'arch_disk_io*' THEN 'worker'
      WHEN t.name = '1.ui' THEN 'flutter_ui'
      WHEN t.name = '1.raster' THEN 'flutter_raster'
      WHEN t.name = 'CrRendererMain' THEN 'webview'
      WHEN t.name GLOB '*Signal Catcher*' THEN 'system'
      ELSE 'other'
    END as role
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
),
-- Step 2: 计算每个线程的四象限分布
thread_quadrant_raw AS (
  SELECT
    pt.utid,
    pt.tid,
    pt.thread_name,
    pt.role,
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    SUM(
      MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})
    ) / 1e6 as dur_ms
  FROM thread_state ts
  JOIN process_threads pt ON ts.utid = pt.utid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
  GROUP BY pt.utid, ts.state, ts.cpu
),
thread_quadrants AS (
  SELECT
    utid, tid, thread_name, role,
    -- CPU 时间 = 所有 Running 时间
    ROUND(SUM(CASE WHEN state = 'Running' THEN dur_ms ELSE 0 END), 2) as total_cpu_ms,
    -- Q1: 大核运行（prime/big/medium 归入性能核侧）
    ROUND(SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium')
      THEN dur_ms ELSE 0 END), 2) as q1_big_running_ms,
    -- Q2: 小核运行
    ROUND(SUM(CASE WHEN state = 'Running' AND core_type = 'little'
      THEN dur_ms ELSE 0 END), 2) as q2_little_running_ms,
    -- Q3: Runnable 等待（含 R 和 R+）
    ROUND(SUM(CASE WHEN state IN ('R', 'R+')
      THEN dur_ms ELSE 0 END), 2) as q3_runnable_ms,
    -- Q4a: 不可中断等待（D/DK）；需结合 io_wait/blocked_function 才能判为 IO
    ROUND(SUM(CASE WHEN state IN ('D', 'DK')
      THEN dur_ms ELSE 0 END), 2) as q4a_io_blocked_ms,
    -- Q4b: 睡眠等待（S/I）
    ROUND(SUM(CASE WHEN state IN ('S', 'I')
      THEN dur_ms ELSE 0 END), 2) as q4b_sleeping_ms,
    -- 总状态时间（该线程的分母）
    ROUND(SUM(dur_ms), 2) as total_ms
  FROM thread_quadrant_raw
  GROUP BY utid
  HAVING total_cpu_ms > 0.5  -- 过滤 CPU 时间 < 0.5ms 的噪声线程
),
-- Step 3: 计算核迁移
sched_events AS (
  SELECT
    pt.utid,
    ss.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    LAG(ss.cpu) OVER (PARTITION BY pt.utid ORDER BY ss.ts) as prev_cpu,
    LAG(COALESCE(ct.core_type, 'unknown')) OVER (PARTITION BY pt.utid ORDER BY ss.ts) as prev_core_type
  FROM sched_slice ss
  JOIN process_threads pt ON ss.utid = pt.utid
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.ts >= ${start_ts} AND ss.ts < ${end_ts}
),
thread_migrations AS (
  SELECT
    utid,
    SUM(CASE WHEN prev_cpu IS NOT NULL AND cpu != prev_cpu THEN 1 ELSE 0 END) as migrations,
    SUM(CASE WHEN prev_cpu IS NOT NULL AND cpu != prev_cpu
              AND core_type != prev_core_type THEN 1 ELSE 0 END) as cross_cluster_migrations
  FROM sched_events
  GROUP BY utid
)
-- Final: 合并四象限 + 摆核数据
SELECT
  tq.thread_name,
  tq.tid,
  tq.role,
  tq.total_cpu_ms,
  tq.q1_big_running_ms,
  tq.q2_little_running_ms,
  tq.q3_runnable_ms,
  tq.q4a_io_blocked_ms,
  tq.q4b_sleeping_ms,
  tq.total_ms,
  -- 百分比
  ROUND(100.0 * tq.total_cpu_ms / NULLIF(tq.total_ms, 0), 1) as running_pct,
  ROUND(100.0 * tq.q1_big_running_ms / NULLIF(tq.total_cpu_ms, 0), 1) as big_core_pct,
  -- 摆核
  COALESCE(tm.migrations, 0) as migrations,
  COALESCE(tm.cross_cluster_migrations, 0) as cross_cluster_migrations
FROM thread_quadrants tq
LEFT JOIN thread_migrations tm ON tq.utid = tm.utid
ORDER BY
  CASE tq.role WHEN 'main' THEN 0 ELSE 1 END,
  tq.total_cpu_ms DESC
LIMIT ${top_k|15}
