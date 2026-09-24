-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: 3bf11270d8e25d4d0471955b857c8d086163252df80124bfb7e57983b0ee2574
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

-- Perfetto 只把 waker_utid 记录在唤醒后的第一个 R/R+ 行上；S/D 等待行自身的
-- waker_utid 为 NULL。回连后继行解析唤醒者的逻辑现在由
-- fragments/sleep_wake_source.sql 统一提供，这里只做主线程取范围和聚合。
-- wake_source / wait_class 是候选标签：irq 唤醒既可能是 NET_RX 软中断，也
-- 可能是定时器到期，单独不足以判定原因。
-- GROUP BY 把这两个标签和 waker_role 一起计入分组键，所以一行是「某唤醒者
-- 的某一种唤醒」而不是「某唤醒者」；合计要自行把同一线程的各行相加。
WITH
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

-- Inputs: wake_source_scope(utid) chooses the sleeping threads;
-- ${start_ts}/${end_ts} bound the scan. Output: wake_source_waits, one row per
-- sleep with its waker read off the wakeup row. The labels (wake_source,
-- wait_class) come from fragments/sleep_wake_source_labels.sql, which every
-- consumer includes after this one; the critical-path engine feeds that same
-- labels fragment its own per-segment wake_source_waits instead of this scan.
--
-- Why the successor row is read instead of the sleep row: Perfetto records
-- waker_utid and irq_context on the first R/R+ row AFTER a sleep, never on the
-- S/D row itself, so each wait is re-linked to the row that starts at its end
-- timestamp. One wake can be split into R then R+, so MAX collapses a wait to
-- one row.
--
-- Why this exists at all: on Android, sched_blocked_reason is emitted only for
-- TASK_UNINTERRUPTIBLE (android14-6.1 try_to_wake_up, android16-6.12
-- __schedule), so thread_state.blocked_function is NULL on every S row. Socket
-- receive and epoll waits are S. The wake source is the only kernel-side
-- signal left for them.
--
-- D/DK rows are carried too, so a blocking-chain consumer can attribute
-- uninterruptible waits with the same vocabulary; blocked_function stays the
-- D-only kernel signal and is not replaced by anything here.
wake_source_waits AS (
  SELECT s.id AS state_id, s.utid, s.ts, s.dur, s.state,
    s.blocked_function, s.io_wait,
    MAX(n.waker_utid) AS waker_utid,
    MAX(n.irq_context) AS irq_context
  FROM thread_state s
  JOIN wake_source_scope sc ON sc.utid = s.utid
  LEFT JOIN thread_state n
    ON n.utid = s.utid
    AND n.ts = s.ts + s.dur
    AND n.state IN ('R', 'R+')
    AND n.waker_utid IS NOT NULL
  WHERE s.state IN ('S', 'I', 'D', 'DK')
    AND s.dur > 0
    AND s.ts < ${end_ts}
    AND s.ts + s.dur > ${start_ts}
  GROUP BY s.id
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Inputs: wake_source_waits(state_id, utid, ts, dur, state, blocked_function,
-- io_wait, waker_utid, irq_context) — from fragments/sleep_wake_source.sql, or
-- any producer of the same columns — and thread_roles from
-- fragments/thread_role.sql. Output: sleep_wake_source, the waits with their
-- wake_source and wait_class labels. Keeping the labels apart from the scan lets
-- a consumer that already knows which sleeps matter (the critical-path engine,
-- per chain segment) label exactly those instead of scanning whole threads.
--
-- A binder waker is recognised by thread_roles.role, not by a second name
-- pattern here: Android 12+ uses lowercase `binder:<pid>_<n>`, and a duplicated
-- `Binder:*` test would silently drop almost every binder wake back into
-- worker_handoff. The binder test runs before the same-process test because an
-- in-process binder pool thread delivering a transaction is a binder wake, not
-- an application hand-off.
--
-- wait_class is a CANDIDATE label, never a root cause. An irq-context wake is
-- equally a NET_RX softirq, a timer expiry (Object.wait(timeout), Thread.sleep,
-- epoll timeout) and a device interrupt; only combining it with the sleeping
-- thread's role narrows it, and only an rx packet correlation confirms it.
wake_source_facts AS (
  SELECT w.state_id, w.utid, sr.tid, sr.thread_name, sr.role AS thread_role,
    sr.upid, sr.process_name, w.ts, w.dur, w.ts + w.dur AS wake_ts, w.state,
    w.blocked_function, w.io_wait,
    w.waker_utid, wr.tid AS waker_tid, wr.thread_name AS waker_thread_name,
    wr.upid AS waker_upid, wr.process_name AS waker_process_name,
    COALESCE(wr.role, 'unknown') AS waker_role,
    COALESCE(w.irq_context, 0) AS irq_context,
    wr.tid = 0 OR wr.thread_name GLOB 'swapper*' AS waker_is_idle,
    wr.role = 'binder' AS waker_is_binder,
    wr.upid IS NOT NULL AND wr.upid = sr.upid AS waker_in_same_process,
    wr.process_name = 'system_server'
      OR wr.process_name GLOB '*surfaceflinger'
      OR wr.process_name GLOB '*netd'
      OR wr.process_name GLOB 'vendor.*'
      OR wr.process_name GLOB 'android.hardware.*'
      OR wr.process_name GLOB '/vendor/bin/*' AS waker_is_system
  FROM wake_source_waits w
  JOIN thread_roles sr ON sr.utid = w.utid
  LEFT JOIN thread_roles wr ON wr.utid = w.waker_utid
),
-- The two labels are derived from ONE set of facts on purpose: a second copy of
-- the binder / same-process / system-process tests could drift and then report a
-- wake_source and a wait_class that contradict each other on the same row.
sleep_wake_source AS (
  SELECT f.state_id, f.utid, f.tid, f.thread_name, f.thread_role,
    f.upid, f.process_name, f.ts, f.dur, f.wake_ts, f.state,
    f.blocked_function, f.io_wait,
    f.waker_utid, f.waker_tid, f.waker_thread_name,
    f.waker_upid, f.waker_process_name, f.waker_role, f.irq_context,
    CASE
      WHEN f.irq_context = 1 THEN 'irq_or_softirq'
      WHEN f.waker_utid IS NULL THEN 'unknown'
      WHEN f.waker_is_idle THEN 'swapper'
      WHEN f.waker_is_binder THEN 'binder_thread'
      WHEN f.waker_in_same_process THEN 'same_process_thread'
      WHEN f.waker_is_system THEN 'system_process'
      ELSE 'unknown'
    END AS wake_source,
    CASE
      WHEN f.irq_context = 1 AND f.thread_role = 'network'
        AND f.state IN ('S', 'I') THEN 'network_receive_candidate'
      WHEN f.irq_context = 1 THEN 'timer_or_device_wake'
      WHEN f.waker_utid IS NULL THEN 'unknown'
      WHEN f.waker_is_binder THEN 'binder_reply'
      WHEN f.waker_in_same_process THEN 'worker_handoff'
      WHEN f.waker_is_system THEN 'system_service'
      ELSE 'unknown'
    END AS wait_class
  FROM wake_source_facts f
)
,
main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = '${process_name}' OR p.name GLOB '${process_name}*')
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  ORDER BY
    (p.name = '${process_name}') DESC,
    EXISTS(SELECT 1 FROM thread_state ts WHERE ts.utid = t.utid) DESC,
    t.utid
  LIMIT 1
),
wake_source_scope AS (
  SELECT utid FROM main_thread
),
waits AS (
  SELECT
    s.wake_ts AS wakeup_ts,
    s.dur AS sleep_dur,
    s.blocked_function,
    s.waker_thread_name,
    s.waker_process_name,
    s.waker_role,
    s.wake_source,
    s.wait_class
  FROM sleep_wake_source s
  WHERE s.state IN ('S', 'D')
    AND s.waker_utid IS NOT NULL
)
SELECT
  printf('%d', MIN(wakeup_ts)) as ts,
  waker_thread_name,
  waker_process_name,
  waker_role,
  wake_source,
  wait_class,
  blocked_function,
  ROUND(SUM(sleep_dur) / 1e6, 2) as total_sleep_dur_ms,
  ROUND(MAX(sleep_dur) / 1e6, 2) as max_sleep_dur_ms,
  COUNT(*) as wakeup_count
FROM waits
GROUP BY waker_thread_name, waker_process_name, waker_role,
  wake_source, wait_class, blocked_function
ORDER BY SUM(sleep_dur) DESC
LIMIT 15
