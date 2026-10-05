-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_jit_analysis.skill.yaml
-- Source SHA-256: b561682b7e303ed5f89648b3b2fd25c2528fe4cd9e5f4fe111646884bf4ea283

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Global CPU spans retain peer identity. Consumers join system_target_threads
-- explicitly; no global process-table replacement or synthetic switch boundary.
-- Capacity extrema require a complete machine population. A missing capacity
-- on any CPU prevents certifying which recorded CPU is fastest or smallest.
-- Big/little rollups over core_type follow the contract in
-- atomic/cpu_topology_view.skill.yaml (big group = prime/big/medium).
system_cpu_topology AS (
  SELECT c.id AS ucpu,c.cpu,c.machine_id,c.cluster_id,c.capacity,
    CASE WHEN c.recorded_capacity_count<c.machine_cpu_count THEN 'unknown'
      WHEN c.min_capacity=c.max_capacity THEN 'unknown'
      WHEN c.capacity=c.min_capacity THEN 'little'
      WHEN c.capacity=c.max_capacity THEN 'big'
      ELSE 'medium' END AS core_type,
    CASE WHEN c.recorded_capacity_count=0 THEN 'capacity_unavailable'
      WHEN c.recorded_capacity_count<c.machine_cpu_count THEN 'capacity_incomplete'
      WHEN c.min_capacity=c.max_capacity THEN 'capacity_uniform_no_big_little'
      ELSE 'recorded_capacity' END AS topology_source
  FROM (
    SELECT cpu.*,
      COUNT(*) OVER (PARTITION BY machine_id) AS machine_cpu_count,
      COUNT(CASE WHEN capacity>0 THEN 1 END) OVER (PARTITION BY machine_id) AS recorded_capacity_count,
      MIN(CASE WHEN capacity>0 THEN capacity END) OVER (PARTITION BY machine_id) AS min_capacity,
      MAX(CASE WHEN capacity>0 THEN capacity END) OVER (PARTITION BY machine_id) AS max_capacity
    FROM cpu
  ) c
),
system_sched_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    s.id AS sched_id, s.utid, t.upid, t.is_idle, s.cpu, s.ucpu,
    s.ts AS raw_start_ts, s.dur AS raw_dur,
    CASE WHEN s.dur >= 0 THEN s.ts + s.dur END AS raw_end_ts,
    MAX(s.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE s.ts + s.dur END, w.window_end_ts) - MAX(s.ts, w.window_start_ts) AS dur_ns,
    s.dur = -1 AS is_unfinished,
    s.ts < w.window_start_ts AS left_censored,
    s.dur = -1 OR s.ts + s.dur > w.window_end_ts AS right_censored,
    s.end_state, s.priority,
    ct.machine_id, ct.cluster_id, ct.capacity,
    COALESCE(ct.core_type, 'unknown') AS core_type,
    COALESCE(ct.topology_source, 'cpu_identity_unavailable') AS topology_source
  FROM system_windows w JOIN sched_slice s
    ON s.ts < w.window_end_ts AND s.dur >= -1 AND s.dur != 0
      AND CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
        ELSE s.ts + s.dur END > w.window_start_ts
  LEFT JOIN thread t ON t.utid = s.utid
  LEFT JOIN system_cpu_topology ct ON ct.ucpu = s.ucpu
  WHERE w.window_end_ts > w.window_start_ts
)
,
jit_threads AS (
  SELECT t.utid, t.name as thread_name
  FROM thread t
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL
      OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.name GLOB 'Jit thread pool*'
         OR t.name GLOB 'Profile Saver*')
),
-- JIT 线程的 CPU 时间和核类型
-- 核类型来自 fragments/system_sched_spans.sql 的 system_cpu_topology（只按 capacity 分级）。
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
jit_cpu AS (
  SELECT ss.core_type, SUM(ss.dur_ns) / 1e6 as running_ms
  FROM system_sched_spans ss
  JOIN jit_threads jt ON ss.utid = jt.utid
  GROUP BY ss.core_type
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
