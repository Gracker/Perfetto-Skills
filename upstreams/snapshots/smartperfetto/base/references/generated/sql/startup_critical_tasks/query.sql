-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_critical_tasks.skill.yaml
-- Source SHA-256: 7d1fb6e3724c17a9610aa5aa28d054f13a96c7a2ee6e955ac720bfcaee25de9f
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

-- Step 1: 识别目标进程的所有线程并自动分配角色
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

-- No input CTE. One role per utid for EVERY thread in the trace, because a
-- waker usually sits outside the analyzed process: a role table scoped to one
-- package cannot name who did the waking.
--
-- Android thread comm is truncated to 15 characters (TASK_COMM_LEN - 1), so a
-- real capture carries `ReferenceQueueD`, `pool-10-thread-`, `RxCachedWorkerP`.
-- A rule that depends on the tail of the full name therefore matches nothing on
-- a device trace: `*ReferenceQueueDaemon*` never fires, and `pool-*-thread-*`
-- silently drops every pool numbered 10 and above.
--
-- Most rules are anchored prefix GLOBs for that reason. Six are deliberately
-- contains-GLOBs — `*Network*`, `*decode*`, `*Decode*`, `*Dispatcher*`,
-- `*Executor*` and `*Worker*` — because the word that names the role sits after
-- a library-specific prefix and still fits inside the truncated comm. They run
-- last within their role and after the earlier roles, so a prefix rule always
-- wins over them.
--
-- The role is a NAME-derived hint about what a thread is conventionally used
-- for. It is not evidence about what the thread did in this window, and it
-- never establishes on its own that a wait was network, image or IO work.
-- `main` is resolved from tid = pid and wins over every name rule; pid 0 is
-- excluded so swapper/idle does not read as somebody's main thread.
-- GLOB is case-sensitive and Android 12+ renames binder pool threads to
-- lowercase `binder:<pid>_<n>`: on the corpus traces 240 of 245 binder threads
-- are lowercase, so a `Binder:*`-only rule classifies almost all of them as
-- `other` and makes every binder wake read as an ordinary worker hand-off.
--
-- This is the only definition of the rules: the critical-path engine reads the
-- roles through fragments/segment_wake_sources.sql rather than a copy, and
-- backend/src/services/__tests__/threadRoleContract.test.ts executes the
-- fragment to pin each role.
thread_roles AS (
  SELECT t.utid, t.tid, t.name AS thread_name, t.upid,
    p.pid AS process_pid, p.name AS process_name,
    CASE
      WHEN p.pid IS NOT NULL AND p.pid > 0 AND t.tid = p.pid THEN 'main'
      WHEN t.name GLOB 'RenderThread*' THEN 'render'
      WHEN t.name GLOB 'HeapTaskDaemon*'
        OR t.name GLOB 'FinalizerDaemon*'
        OR t.name GLOB 'ReferenceQueueD*' THEN 'gc'
      WHEN t.name GLOB 'Jit thread pool*'
        OR t.name GLOB 'Profile Saver*' THEN 'jit'
      WHEN t.name GLOB 'Binder:*'
        OR t.name GLOB 'binder:*'
        OR t.name GLOB 'HwBinder:*'
        OR t.name GLOB 'hwbinder:*' THEN 'binder'
      WHEN t.name GLOB 'OkHttp*'
        OR t.name GLOB 'Okio*'
        OR t.name GLOB 'Cronet*'
        OR t.name GLOB 'ChromiumNet*'
        OR t.name GLOB 'NetworkThread*'
        OR t.name GLOB '*Network*' THEN 'network'
      WHEN t.name GLOB 'glide*'
        OR t.name GLOB 'Glide*'
        OR t.name GLOB 'Coil*'
        OR t.name GLOB 'Fresco*'
        OR t.name GLOB '*decode*'
        OR t.name GLOB '*Decode*' THEN 'image'
      WHEN t.name GLOB 'pool-*'
        OR t.name GLOB 'AsyncTask*'
        OR t.name GLOB 'arch_disk_io*'
        OR t.name GLOB 'RxCached*'
        OR t.name GLOB 'DefaultDispatcher*'
        OR t.name GLOB 'Dispatchers.Default*'
        OR t.name GLOB '*Dispatcher*'
        OR t.name GLOB '*Executor*'
        OR t.name GLOB '*Worker*' THEN 'worker'
      WHEN t.name GLOB '1.ui' THEN 'flutter_ui'
      WHEN t.name GLOB '1.raster' THEN 'flutter_raster'
      WHEN t.name GLOB 'CrRendererMain*' THEN 'webview'
      WHEN t.name GLOB 'Signal Catcher*' THEN 'system'
      ELSE 'other'
    END AS role
  FROM thread t
  LEFT JOIN process p ON p.upid = t.upid
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Inputs: system_windows(window_id, window_start_ts, window_end_ts),
-- system_target_threads(window_id, upid, utid, role). Half-open intersections.
-- Unfinished states are observed only through the trace bound; clipping never
-- converts that bound into a real switch/wakeup event.
system_thread_state_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    tt.upid, tt.utid, tt.role, ts.id AS thread_state_id,
    ts.ts AS raw_start_ts, ts.dur AS raw_dur,
    CASE WHEN ts.dur >= 0 THEN ts.ts + ts.dur END AS raw_end_ts,
    MAX(ts.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END, w.window_end_ts) - MAX(ts.ts, w.window_start_ts) AS dur_ns,
    ts.dur = -1 AS is_unfinished,
    ts.ts < w.window_start_ts AS left_censored,
    ts.dur = -1 OR ts.ts + ts.dur > w.window_end_ts AS right_censored,
    ts.state, ts.cpu, ts.ucpu, ts.io_wait, ts.blocked_function, ts.waker_utid, ts.irq_context
  FROM system_windows w
  JOIN system_target_threads tt ON tt.window_id = w.window_id
  JOIN thread_state ts ON ts.utid = tt.utid
  WHERE w.window_end_ts > w.window_start_ts AND ts.dur != 0 AND ts.dur >= -1
    AND ts.ts < w.window_end_ts
    AND CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE ts.ts + ts.dur END > w.window_start_ts
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Global CPU spans retain peer identity. Consumers join system_target_threads
-- explicitly; no global process-table replacement or synthetic switch boundary.
-- Capacity extrema require a complete machine population. A missing capacity
-- on any CPU prevents certifying which recorded CPU is fastest or smallest.
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
system_windows AS (SELECT 0 AS window_id,
  COALESCE(${start_ts},(SELECT start_ts FROM trace_bounds)) AS window_start_ts,
  COALESCE(${end_ts},(SELECT end_ts FROM trace_bounds)) AS window_end_ts),
system_target_threads AS (
  SELECT w.window_id,p.upid,t.utid,CASE WHEN t.tid=p.pid THEN 'main' ELSE 'target' END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p JOIN thread t ON t.upid=p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
),
clipped_states AS (SELECT s.*,s.clipped_start_ts AS ts,s.dur_ns AS dur FROM system_thread_state_spans s),
clipped_sched AS (SELECT s.*,s.clipped_start_ts AS ts,s.dur_ns AS dur FROM system_sched_spans s),
process_threads AS (
  SELECT
    tr.utid,
    tr.tid,
    tr.thread_name,
    p.upid,
    p.pid,
    p.name as process_name,
    tr.role
  FROM thread_roles tr
  JOIN effective_target_processes p ON tr.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
),
-- Step 2: 计算每个线程的四象限分布
thread_quadrant_raw AS (
  SELECT
    pt.utid,
    pt.tid,
    pt.thread_name,
    pt.upid,
    pt.pid,
    pt.process_name,
    pt.role,
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    SUM(
      MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})
    ) / 1e6 as dur_ms
  FROM clipped_states ts
  JOIN process_threads pt ON ts.utid = pt.utid
  LEFT JOIN system_cpu_topology ct ON ts.ucpu = ct.ucpu
  WHERE ts.ts < ${end_ts}
    AND ts.ts + ts.dur > ${start_ts}
  GROUP BY pt.utid, ts.state, ts.cpu
),
thread_quadrants AS (
  SELECT
    utid, tid, thread_name, upid, pid, process_name, role,
    -- CPU 时间 = 所有 Running 时间
    ROUND(SUM(CASE WHEN state = 'Running' THEN dur_ms ELSE 0 END), 2) as total_cpu_ms,
    -- Q1: 大核运行（prime/big/medium 归入性能核侧）
    ROUND(SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium')
      THEN dur_ms ELSE 0 END), 2) as q1_big_running_ms,
    -- Q2: 小核运行
    ROUND(SUM(CASE WHEN state = 'Running' AND core_type = 'little'
      THEN dur_ms ELSE 0 END), 2) as q2_little_running_ms,
    ROUND(SUM(CASE WHEN state = 'Running' AND core_type NOT IN ('prime', 'big', 'medium', 'little')
      THEN dur_ms ELSE 0 END), 2) as unknown_running_ms,
    SUM(CASE WHEN state = 'Running' AND core_type NOT IN ('prime', 'big', 'medium', 'little')
      THEN dur_ms ELSE 0 END) as unknown_running_unrounded_ms,
    -- Q3: Runnable 等待（含 R 和 R+）
    ROUND(SUM(CASE WHEN state IN ('R', 'R+')
      THEN dur_ms ELSE 0 END), 2) as q3_runnable_ms,
    ROUND(SUM(CASE WHEN state = 'R+' THEN dur_ms ELSE 0 END), 2) as runnable_preempted_ms,
    -- Q4a: 不可中断等待（D/DK）；需结合 io_wait/blocked_function 才能判为 IO
    ROUND(SUM(CASE WHEN state IN ('D', 'DK')
      THEN dur_ms ELSE 0 END), 2) as q4a_uninterruptible_ms,
    -- Q4b: 睡眠等待（S/I）
    ROUND(SUM(CASE WHEN state IN ('S', 'I')
      THEN dur_ms ELSE 0 END), 2) as q4b_sleeping_ms,
    ROUND(SUM(CASE WHEN state NOT IN ('Running', 'R', 'R+', 'D', 'DK', 'S', 'I')
      THEN dur_ms ELSE 0 END), 2) as other_state_ms,
    -- 总状态时间（该线程的分母）
    ROUND(SUM(dur_ms), 2) as total_ms
  FROM thread_quadrant_raw
  GROUP BY utid
  HAVING total_ms > 0
),
-- Step 3: 计算核迁移
sched_events AS (
  SELECT pt.utid,ss.cpu,ss.ucpu,ss.raw_start_ts,ss.sched_id,
    ss.machine_id,ss.cluster_id,
    LAG(ss.ucpu) OVER (PARTITION BY pt.utid ORDER BY ss.raw_start_ts,ss.sched_id) AS prev_ucpu,
    LAG(ss.machine_id) OVER (PARTITION BY pt.utid ORDER BY ss.raw_start_ts,ss.sched_id) AS prev_machine_id,
    LAG(ss.cluster_id) OVER (PARTITION BY pt.utid ORDER BY ss.raw_start_ts,ss.sched_id) AS prev_cluster_id
  FROM clipped_sched ss JOIN process_threads pt ON ss.utid=pt.utid
),
migration_observations AS (
  SELECT utid,
    SUM(CASE WHEN prev_ucpu IS NOT NULL AND ucpu IS NOT NULL AND ucpu!=prev_ucpu THEN 1 ELSE 0 END) AS migrations,
    SUM(CASE WHEN prev_ucpu IS NOT NULL AND ucpu IS NOT NULL AND ucpu!=prev_ucpu
      AND machine_id IS prev_machine_id AND cluster_id IS NOT NULL AND prev_cluster_id IS NOT NULL
      AND cluster_id!=prev_cluster_id THEN 1 ELSE 0 END) AS observed_cross_cluster_migrations,
    SUM(CASE WHEN prev_ucpu IS NOT NULL AND ucpu IS NOT NULL AND ucpu!=prev_ucpu
      AND (NOT (machine_id IS prev_machine_id) OR cluster_id IS NULL OR prev_cluster_id IS NULL)
      THEN 1 ELSE 0 END) AS unknown_cluster_migrations
  FROM sched_events GROUP BY utid
),
thread_migrations AS (
  SELECT *,CASE WHEN unknown_cluster_migrations>0 THEN NULL ELSE observed_cross_cluster_migrations END AS cross_cluster_migrations,
    CASE WHEN unknown_cluster_migrations>0 THEN 'partial_cluster_identity'
      ELSE 'observed_within_window_transitions' END AS migration_evidence
  FROM migration_observations
),
-- kernel priority is an observation, not an inferred FIFO/RR/nice policy.
sched_priorities AS (
  SELECT ss.utid, COUNT(*) as sched_count,
    MIN(ss.priority) as priority_min, MAX(ss.priority) as priority_max,
    COUNT(DISTINCT ss.priority) as priority_value_count
  FROM clipped_sched ss JOIN process_threads pt ON ss.utid = pt.utid
  WHERE ss.dur > 0 AND ss.ts < ${end_ts} AND ss.ts + ss.dur > ${start_ts}
  GROUP BY ss.utid
),
observed_preemptions AS (
  SELECT ss.utid, COUNT(*) as preemption_count
  FROM clipped_sched ss JOIN process_threads pt ON ss.utid = pt.utid
  WHERE ss.dur > 0 AND ss.end_state = 'R+'
    AND ss.ts + ss.dur >= ${start_ts} AND ss.ts + ss.dur < ${end_ts}
  GROUP BY ss.utid
)
-- Final: 合并四象限 + 摆核数据
SELECT
  (SELECT window_start_ts FROM system_windows) AS window_start_ts,
  (SELECT window_end_ts FROM system_windows) AS window_end_ts,
  COUNT(*) OVER () AS total_observed_threads,
  tq.upid,
  tq.pid,
  tq.process_name,
  tq.utid,
  tq.thread_name,
  tq.tid,
  tq.role,
  tq.total_cpu_ms,
  tq.q1_big_running_ms,
  tq.q2_little_running_ms,
  tq.unknown_running_ms,
  tq.other_state_ms,
  tq.q3_runnable_ms,
  tq.runnable_preempted_ms,
  tq.q4a_uninterruptible_ms,
  tq.q4b_sleeping_ms,
  tq.total_ms,
  -- 百分比
  ROUND(100.0 * tq.total_cpu_ms / NULLIF(tq.total_ms, 0), 1) as running_pct,
  CASE WHEN tq.unknown_running_unrounded_ms > 0 THEN NULL
    ELSE ROUND(100.0 * tq.q1_big_running_ms / NULLIF(tq.total_cpu_ms, 0), 1) END as big_core_pct,
  -- 摆核
  tm.migrations,
  tm.cross_cluster_migrations,
  tm.observed_cross_cluster_migrations,
  tm.unknown_cluster_migrations,
  COALESCE(tm.migration_evidence, 'sched_slice_unavailable') AS migration_evidence,
  sp.priority_min,
  sp.priority_max,
  COALESCE(sp.priority_value_count, 0) as priority_value_count,
  CASE WHEN sp.sched_count IS NULL AND op.preemption_count IS NULL THEN NULL
    ELSE COALESCE(op.preemption_count, 0) END as preemption_count,
  CASE WHEN sp.sched_count IS NULL THEN 'sched_slice_unavailable'
    WHEN sp.priority_value_count = 0 THEN 'kernel_priority_unavailable'
    ELSE 'observed_kernel_priority_only' END as priority_evidence,
  'not_recorded_in_sched_slice' as scheduling_policy_evidence
FROM thread_quadrants tq
LEFT JOIN thread_migrations tm ON tq.utid = tm.utid
LEFT JOIN sched_priorities sp ON tq.utid = sp.utid
LEFT JOIN observed_preemptions op ON tq.utid = op.utid
ORDER BY
  CASE tq.role WHEN 'main' THEN 0 ELSE 1 END,
  tq.total_cpu_ms DESC
LIMIT ${top_k|15}
