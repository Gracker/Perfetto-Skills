-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/sleep_wake_source_labels.sql
-- Source SHA-256: 5b87f6089e3eeed84762e2e763512e2828930584ca7da366f99655008cb11e6c
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
