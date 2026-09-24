-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/sleep_wake_source.sql
-- Source SHA-256: 295fc90c1d1cbc5f87acda56779324a263e5589cdb97f3e0da3ae5a8548965b1
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

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
