-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_pool_saturation_in_range.skill.yaml
-- Source SHA-256: d97947f0d5741f3e833349e9213a342b2eeb780815b6c1a53cba62ccf235a939

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
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Input: system_windows(window_id, window_start_ts, window_end_ts). Requires
-- fragments/effective_target_processes.sql. Parameters: package (the process
-- name or its name:* subprocesses, '' for any), utid (one thread, else NULL).
-- An exact process scope binds the UPID and ignores package.
--   system_target_processes  window x target process (upid, pid, name)
--   system_target_threads    window x target thread; role is main for the
--                            thread whose tid is the process pid, else target
system_target_processes AS (
  SELECT w.window_id, p.upid, p.pid, p.name
  FROM system_windows w CROSS JOIN effective_target_processes p
  WHERE ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}' OR p.name GLOB '${package}:*'
),
system_target_threads AS (
  SELECT tp.window_id, tp.upid, t.utid,
    CASE WHEN t.tid = tp.pid THEN 'main' ELSE 'target' END AS role
  FROM system_target_processes tp
  JOIN thread t ON t.upid = tp.upid
  WHERE ${utid} IS NULL OR t.utid = ${utid}
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
--
-- `binder_named` is the binder thread-name rule on its own, independent of the
-- main-wins precedence: a native service whose main thread joined its binder
-- pool keeps role `main` and is still binder_named, so a binder-pool reader
-- uses this column rather than a second copy of the name rule.
thread_roles AS (
  SELECT t.utid, t.tid, t.name AS thread_name, t.upid,
    p.pid AS process_pid, p.name AS process_name, t.binder_named,
    CASE
      WHEN p.pid IS NOT NULL AND p.pid > 0 AND t.tid = p.pid THEN 'main'
      WHEN t.name GLOB 'RenderThread*' THEN 'render'
      WHEN t.name GLOB 'HeapTaskDaemon*'
        OR t.name GLOB 'FinalizerDaemon*'
        OR t.name GLOB 'ReferenceQueueD*' THEN 'gc'
      WHEN t.name GLOB 'Jit thread pool*'
        OR t.name GLOB 'Profile Saver*' THEN 'jit'
      WHEN t.binder_named THEN 'binder'
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
  FROM (
    SELECT thread.*,
      COALESCE(name GLOB 'Binder:*' OR name GLOB 'binder:*'
        OR name GLOB 'HwBinder:*' OR name GLOB 'hwbinder:*', 0) AS binder_named
    FROM thread
  ) t
  LEFT JOIN process p ON p.upid = t.upid
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Input: system_windows(window_id, window_start_ts, window_end_ts). Requires
-- fragments/effective_target_processes.sql, fragments/system_target_threads.sql
-- (system_target_processes) and fragments/thread_role.sql (binder_named,
-- the binder thread-name rule). Read from the binder slices themselves (not only
-- android_binder_txns, which drops calls that never completed):
--   binder_pool_call_slices      `binder transaction` slices overlapping the
--                                window, with their raw end (an unfinished
--                                call ends at the trace end) and destination pid
--   binder_pool_sync_calls       those client-side synchronous calls with the
--                                server reply (by flow) when one exists and the
--                                server process from the reply thread, else
--                                from the `destination process` arg
--   binder_pool_target_processes the target process (target_process) and the
--                                servers of the sync calls of its main thread in
--                                the window (sync_binder_server)
--   binder_pool_named_threads    per target, threads the binder name rule of
--                                thread_roles matches (binder_named)
--   binder_pool_threads          those the trace shows active (a thread_state
--                                row or a slice): the observed pool. A named
--                                thread with neither is a phantom left out
--   binder_pool_busy             the depth-0 slices (any name) of each pool
--                                thread overlapping the window: a pool thread
--                                is busy while one covers it, idle ones carry
--                                none; an unfinished slice (dur = -1) is busy
--                                until the trace end
--   binder_pool_replies          the `binder reply` slices of each pool thread
--                                overlapping the window (descriptive)
binder_pool_call_slices AS MATERIALIZED (
  SELECT * FROM (
    SELECT w.window_id, w.window_start_ts, w.window_end_ts, c.id, c.ts, c.dur, c.track_id,
      CASE WHEN c.dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE c.ts + c.dur END AS raw_end_ts,
      extract_arg(c.arg_set_id, 'destination process') AS destination_pid
    FROM system_windows w
    JOIN slice c ON c.name = 'binder transaction' AND c.dur >= -1 AND c.ts < w.window_end_ts
    WHERE w.window_end_ts > w.window_start_ts
  ) WHERE raw_end_ts > window_start_ts
),
binder_pool_call_replies AS (
  SELECT f.slice_out AS call_slice_id, MIN(f.slice_in) AS reply_slice_id
  FROM binder_pool_call_slices c
  JOIN flow f ON f.slice_out = c.id
  JOIN slice r ON r.id = f.slice_in AND r.name = 'binder reply'
  GROUP BY f.slice_out
),
binder_pool_sync_calls AS MATERIALIZED (
  SELECT c.window_id, c.id AS call_slice_id, c.ts AS call_ts, c.dur AS call_dur,
    MAX(c.ts, c.window_start_ts) AS wait_start_ts, MIN(c.raw_end_ts, c.window_end_ts) AS wait_end_ts,
    c.dur = -1 AS is_unfinished,
    ct.utid AS client_utid, ct.tid AS client_tid, ct.name AS client_thread_name, ct.upid AS client_upid,
    r.id AS reply_slice_id, r.dur AS reply_dur, rt.utid AS server_utid, rt.tid AS server_tid,
    rt.name AS server_thread_name,
    COALESCE(rt.upid, (
      SELECT dp.upid FROM process dp
      WHERE dp.pid = c.destination_pid
        AND (dp.start_ts IS NULL OR dp.start_ts <= c.ts) AND (dp.end_ts IS NULL OR dp.end_ts >= c.ts)
      ORDER BY dp.upid DESC LIMIT 1)) AS server_upid
  FROM binder_pool_call_slices c
  JOIN thread_track ctt ON ctt.id = c.track_id
  JOIN thread ct ON ct.utid = ctt.utid
  LEFT JOIN binder_pool_call_replies cr ON cr.call_slice_id = c.id
  LEFT JOIN slice r ON r.id = cr.reply_slice_id
  LEFT JOIN thread_track rtt ON rtt.id = r.track_id
  LEFT JOIN thread rt ON rt.utid = rtt.utid
),
binder_pool_target_processes AS MATERIALIZED (
  SELECT window_id, upid, MAX(target_role) AS target_role
  FROM (
    SELECT tp.window_id, tp.upid, 'target_process' AS target_role
    FROM system_target_processes tp JOIN system_windows w ON w.window_id = tp.window_id
    WHERE w.window_end_ts > w.window_start_ts
    UNION ALL
    SELECT sc.window_id, sc.server_upid, 'sync_binder_server'
    FROM binder_pool_sync_calls sc
    JOIN system_target_processes cp ON cp.window_id = sc.window_id AND cp.upid = sc.client_upid
      AND cp.pid = sc.client_tid
    WHERE sc.server_upid IS NOT NULL
  )
  GROUP BY window_id, upid
),
binder_pool_named_threads AS MATERIALIZED (
  SELECT tp.window_id, tp.upid, t.utid
  FROM binder_pool_target_processes tp
  JOIN thread t ON t.upid = tp.upid
  JOIN thread_roles tr ON tr.utid = t.utid
  WHERE tr.binder_named
),
binder_pool_active_threads AS MATERIALIZED (
  SELECT DISTINCT s.utid FROM thread_state s
  WHERE s.utid IN (SELECT utid FROM binder_pool_named_threads)
  UNION
  SELECT tt.utid FROM thread_track tt
  WHERE tt.utid IN (SELECT utid FROM binder_pool_named_threads)
    AND EXISTS (SELECT 1 FROM slice s WHERE s.track_id = tt.id)
),
-- One pass over the reply slices, kept only for named target threads.
binder_pool_reply_threads AS MATERIALIZED (
  SELECT DISTINCT tt.utid
  FROM slice r
  CROSS JOIN thread_track tt ON tt.id = r.track_id
  WHERE r.name = 'binder reply' AND tt.utid IN (SELECT utid FROM binder_pool_named_threads)
),
binder_pool_threads AS MATERIALIZED (
  SELECT nt.window_id, nt.upid, nt.utid, rt.utid IS NOT NULL AS served_reply
  FROM binder_pool_named_threads nt
  JOIN binder_pool_active_threads at ON at.utid = nt.utid
  LEFT JOIN binder_pool_reply_threads rt ON rt.utid = nt.utid
),
-- Depth-0 and `binder reply` slices of the pool threads overlapping the window.
binder_pool_thread_slices AS MATERIALIZED (
  SELECT window_id, upid, utid, slice_id, slice_name, slice_depth, slice_ts, slice_dur,
    MAX(slice_ts, window_start_ts) AS busy_start_ts, MIN(raw_end_ts, window_end_ts) AS busy_end_ts,
    slice_dur = -1 AS is_unfinished
  FROM (
    SELECT pt.window_id, pt.upid, pt.utid, w.window_start_ts, w.window_end_ts,
      s.id AS slice_id, s.name AS slice_name, s.depth AS slice_depth, s.ts AS slice_ts, s.dur AS slice_dur,
      CASE WHEN s.dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE s.ts + s.dur END AS raw_end_ts
    FROM binder_pool_threads pt
    JOIN system_windows w ON w.window_id = pt.window_id
    JOIN thread_track tt ON tt.utid = pt.utid
    JOIN slice s ON s.track_id = tt.id AND (s.depth = 0 OR s.name = 'binder reply')
      AND s.dur >= -1 AND s.ts < w.window_end_ts
  ) WHERE raw_end_ts > window_start_ts
),
binder_pool_busy AS (
  SELECT window_id, upid, utid, slice_id, slice_name, slice_ts, slice_dur, busy_start_ts, busy_end_ts, is_unfinished
  FROM binder_pool_thread_slices WHERE slice_depth = 0
),
binder_pool_replies AS (
  SELECT window_id, upid, utid, slice_id AS reply_slice_id, slice_ts AS reply_ts, slice_dur AS reply_dur,
    busy_start_ts, busy_end_ts, is_unfinished
  FROM binder_pool_thread_slices WHERE slice_name = 'binder reply'
)
,
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
named AS (
  SELECT window_id, upid, COUNT(*) AS named_binder_threads FROM binder_pool_named_threads GROUP BY window_id, upid
),
pools AS (
  SELECT window_id, upid, COUNT(*) AS pool_size, SUM(served_reply) AS reply_serving_threads
  FROM binder_pool_threads GROUP BY window_id, upid
),
busy_spans AS (
  SELECT window_id, upid, utid, busy_start_ts, busy_end_ts FROM binder_pool_busy WHERE busy_end_ts > busy_start_ts
),
edges AS (
  SELECT window_id, upid, utid, busy_start_ts AS ts, 1 AS delta FROM busy_spans
  UNION ALL
  SELECT window_id, upid, utid, busy_end_ts, -1 FROM busy_spans
),
-- Overlapping busy slices on one thread keep it busy, never busy twice: only
-- the idle->busy and busy->idle edges of a thread change the pool level.
thread_depth AS (
  SELECT *, SUM(delta) OVER (PARTITION BY window_id, utid ORDER BY ts, delta
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS depth_after
  FROM edges
),
level_changes AS (
  SELECT window_id, upid, ts, SUM(delta) AS delta
  FROM thread_depth WHERE (delta = 1 AND depth_after = 1) OR (delta = -1 AND depth_after = 0)
  GROUP BY window_id, upid, ts
),
levels AS (
  SELECT window_id, upid, ts,
    SUM(delta) OVER (PARTITION BY window_id, upid ORDER BY ts) AS busy_threads,
    LEAD(ts) OVER (PARTITION BY window_id, upid ORDER BY ts) AS next_ts
  FROM level_changes
),
occupancy AS (
  SELECT l.window_id, l.upid, MAX(l.busy_threads) AS peak_busy_threads,
    SUM(CASE WHEN l.busy_threads >= pl.pool_size AND l.next_ts IS NOT NULL THEN l.next_ts - l.ts ELSE 0 END) AS saturated_ns,
    SUM(CASE WHEN l.next_ts IS NOT NULL THEN l.busy_threads * (l.next_ts - l.ts) ELSE 0 END) AS busy_thread_ns
  FROM levels l JOIN pools pl ON pl.window_id = l.window_id AND pl.upid = l.upid
  GROUP BY l.window_id, l.upid
),
busy_counts AS (
  SELECT window_id, upid, COUNT(*) AS busy_slices, SUM(is_unfinished) AS unfinished_busy_slices
  FROM binder_pool_busy GROUP BY window_id, upid
),
replies AS (
  SELECT window_id, upid, COUNT(*) AS in_progress_replies, SUM(is_unfinished) AS unfinished_replies
  FROM binder_pool_replies GROUP BY window_id, upid
),
waits AS (
  SELECT window_id, server_upid AS upid, COUNT(*) AS waiting_sync_calls,
    SUM(is_unfinished) AS unreplied_sync_calls,
    SUM(reply_slice_id IS NULL) AS unreceived_sync_calls,
    MAX(wait_end_ts - wait_start_ts) AS max_sync_wait_ns
  FROM binder_pool_sync_calls WHERE server_upid IS NOT NULL
  GROUP BY window_id, server_upid
)
SELECT w.window_start_ts, w.window_end_ts, w.window_end_ts - w.window_start_ts AS window_dur_ns,
  tp.upid, p.pid, p.name AS process_name, tp.target_role,
  COALESCE(pl.pool_size, 0) AS pool_size, 'observed_active_binder_threads' AS pool_size_basis,
  COALESCE(nm.named_binder_threads, 0) AS named_binder_threads,
  COALESCE(nm.named_binder_threads, 0) - COALESCE(pl.pool_size, 0) AS inactive_binder_threads,
  COALESCE(pl.reply_serving_threads, 0) AS reply_serving_threads,
  'depth0_thread_slice' AS busy_basis,
  COALESCE(o.peak_busy_threads, 0) AS peak_busy_threads,
  COALESCE(o.saturated_ns, 0) AS saturated_ns,
  COALESCE(o.busy_thread_ns, 0) AS busy_thread_ns,
  COALESCE(bc.busy_slices, 0) AS busy_slices,
  COALESCE(bc.unfinished_busy_slices, 0) AS unfinished_busy_slices,
  COALESCE(r.in_progress_replies, 0) AS in_progress_replies,
  COALESCE(r.unfinished_replies, 0) AS unfinished_replies,
  COALESCE(wt.waiting_sync_calls, 0) AS waiting_sync_calls,
  COALESCE(wt.unreplied_sync_calls, 0) AS unreplied_sync_calls,
  COALESCE(wt.unreceived_sync_calls, 0) AS unreceived_sync_calls,
  wt.max_sync_wait_ns,
  CASE WHEN COALESCE(pl.pool_size, 0) = 0 THEN 'no_observed_pool_threads'
    WHEN COALESCE(o.saturated_ns, 0) > 0 AND pl.pool_size = 1 THEN 'single_observed_thread_busy'
    WHEN COALESCE(o.saturated_ns, 0) > 0 THEN 'saturated_observed'
    ELSE 'not_saturated_observed' END AS saturation_evidence,
  'observed_pool_not_configured_max' AS evidence_scope,
  CASE WHEN COALESCE(pl.pool_size, 0) = 0 THEN 'not_recorded' ELSE 'observed' END AS pool_evidence_status
FROM binder_pool_target_processes tp
JOIN system_windows w ON w.window_id = tp.window_id
JOIN process p ON p.upid = tp.upid
LEFT JOIN named nm ON nm.window_id = tp.window_id AND nm.upid = tp.upid
LEFT JOIN pools pl ON pl.window_id = tp.window_id AND pl.upid = tp.upid
LEFT JOIN busy_counts bc ON bc.window_id = tp.window_id AND bc.upid = tp.upid
LEFT JOIN occupancy o ON o.window_id = tp.window_id AND o.upid = tp.upid
LEFT JOIN replies r ON r.window_id = tp.window_id AND r.upid = tp.upid
LEFT JOIN waits wt ON wt.window_id = tp.window_id AND wt.upid = tp.upid
ORDER BY CASE tp.target_role WHEN 'target_process' THEN 0 ELSE 1 END,
  COALESCE(o.saturated_ns, 0) DESC, tp.upid
