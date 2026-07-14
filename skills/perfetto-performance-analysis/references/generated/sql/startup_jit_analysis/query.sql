-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_jit_analysis.skill.yaml
-- Source SHA-256: 3b238fd00ac7450afc57b24ada44cbcb0b1c9f11a83cba1a91e1af48addd169a
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH jit_threads AS (
  SELECT t.utid, t.name as thread_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
    AND (t.name GLOB 'Jit thread pool*'
         OR t.name GLOB 'Profile Saver*')
),
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*' AND t.tid = p.pid
  LIMIT 1
),
-- JIT 线程的 CPU 时间和核类型
jit_cpu AS (
  SELECT
    COALESCE(ct.core_type, 'unknown') as core_type,
    SUM(MIN(ss.ts + ss.dur, ${end_ts}) - MAX(ss.ts, ${start_ts})) / 1e6 as running_ms
  FROM sched_slice ss
  JOIN jit_threads jt ON ss.utid = jt.utid
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.ts < ${end_ts} AND ss.ts + ss.dur > ${start_ts}
  GROUP BY core_type
),
-- JIT slice 分析
jit_slices AS (
  SELECT
    CASE
      WHEN s.name GLOB 'JIT compiling*' THEN 'jit_compile'
      WHEN s.name GLOB '*GarbageCollectCache*' THEN 'code_cache_gc'
      WHEN s.name GLOB '*ScopedCodeCacheWrite*' THEN 'code_cache_write'
      WHEN s.name GLOB 'JitProfileTask*' THEN 'profile_task'
      ELSE 'other_jit'
    END as jit_activity,
    COUNT(*) as event_count,
    SUM(s.dur) / 1e6 as total_ms,
    MAX(s.dur) / 1e6 as max_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN jit_threads jt ON tt.utid = jt.utid
  WHERE s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND s.dur > 0
  GROUP BY jit_activity
),
-- 计算摘要指标
summary AS (
  SELECT
    ROUND(COALESCE((SELECT SUM(running_ms) FROM jit_cpu), 0), 1) as jit_total_cpu_ms,
    ROUND(COALESCE((SELECT SUM(running_ms) FROM jit_cpu WHERE core_type IN ('prime', 'big', 'medium')), 0), 1) as jit_big_core_ms,
    ROUND(COALESCE((SELECT SUM(running_ms) FROM jit_cpu WHERE core_type = 'little'), 0), 1) as jit_little_core_ms,
    COALESCE((SELECT event_count FROM jit_slices WHERE jit_activity = 'jit_compile'), 0) as compile_count,
    ROUND(COALESCE((SELECT total_ms FROM jit_slices WHERE jit_activity = 'jit_compile'), 0), 1) as compile_total_ms,
    COALESCE((SELECT event_count FROM jit_slices WHERE jit_activity = 'code_cache_gc'), 0) as code_cache_gc_count,
    ROUND(COALESCE((SELECT total_ms FROM jit_slices WHERE jit_activity = 'code_cache_gc'), 0), 1) as code_cache_gc_ms
)
SELECT 'JIT 总 CPU 时间' as metric,
  ROUND(jit_total_cpu_ms, 1) || ' ms' as value,
  CASE
    WHEN jit_total_cpu_ms > 50 THEN '偏高：JIT 线程占用大量 CPU，建议使用 Baseline Profile'
    WHEN jit_total_cpu_ms > 20 THEN '中等：有一定 JIT 编译活动'
    WHEN jit_total_cpu_ms > 0 THEN '正常'
    ELSE '无 JIT 活动（可能已 AOT 编译）'
  END as assessment
FROM summary
UNION ALL
SELECT 'JIT 大核 CPU 时间' as metric,
  ROUND(jit_big_core_ms, 1) || ' ms (' ||
    ROUND(100.0 * jit_big_core_ms / NULLIF(jit_total_cpu_ms, 0), 0) || '%)' as value,
  CASE
    WHEN jit_big_core_ms > 30 THEN '⚠️ JIT 线程占用大量大核时间，可能与主线程争抢'
    WHEN jit_big_core_ms > 10 THEN '有一定大核竞争'
    ELSE '正常'
  END as assessment
FROM summary
UNION ALL
SELECT 'JIT 编译次数' as metric,
  compile_count || ' 次 (' || ROUND(compile_total_ms, 1) || ' ms)' as value,
  CASE
    WHEN compile_count > 50 THEN '⚠️ 大量 JIT 编译，Baseline Profile 覆盖不足'
    WHEN compile_count > 20 THEN '中等数量 JIT 编译'
    WHEN compile_count > 0 THEN '少量 JIT 编译'
    ELSE '无 JIT 编译'
  END as assessment
FROM summary
UNION ALL
SELECT 'Code Cache GC' as metric,
  code_cache_gc_count || ' 次 (' || ROUND(code_cache_gc_ms, 1) || ' ms)' as value,
  CASE
    WHEN code_cache_gc_count > 0 THEN '⚠️ 触发 Code Cache GC，可能影响启动性能'
    ELSE '未触发'
  END as assessment
FROM summary
