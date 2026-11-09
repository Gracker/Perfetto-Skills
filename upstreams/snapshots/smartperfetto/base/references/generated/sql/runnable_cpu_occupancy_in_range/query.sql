-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/runnable_cpu_occupancy_in_range.skill.yaml
-- Source SHA-256: a49f4b9043c7f6d13ecf147f6202d2d1ffa887e62e7a71c78d89663a5717587f

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
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
-- R/R+ rows, raw and clipped to the window by system_thread_state_spans.
wait_segments AS MATERIALIZED (
  SELECT window_id, upid, utid, role, thread_state_id AS state_id, raw_start_ts, raw_dur,
    clipped_start_ts AS seg_start_ts, dur_ns AS seg_ns
  FROM system_thread_state_spans WHERE state IN ('R', 'R+')
),
target_totals AS (
  SELECT window_id, upid, utid, role, SUM(seg_ns) AS runnable_ns
  FROM wait_segments GROUP BY window_id, upid, utid, role
),
ranked_targets AS (
  SELECT tt.*,
    ROW_NUMBER() OVER (PARTITION BY window_id, role = 'main' ORDER BY runnable_ns DESC, utid) AS target_rank,
    COUNT(*) OVER (PARTITION BY window_id) AS targets_with_runnable
  FROM target_totals tt
),
kept_targets AS MATERIALIZED (
  SELECT *, targets_with_runnable - COUNT(*) OVER (PARTITION BY window_id) AS targets_omitted
  FROM ranked_targets
  WHERE target_rank <= CASE WHEN role = 'main' THEN MAX(${max_targets|4}, 1) ELSE ${max_targets|4} END
),
kept_waits AS MATERIALIZED (
  SELECT s.* FROM wait_segments s JOIN kept_targets k ON k.window_id = s.window_id AND k.utid = s.utid
),
wait_bounds AS (
  SELECT utid, MIN(raw_start_ts) AS first_ts, MAX(raw_start_ts + raw_dur) AS last_end_ts
  FROM kept_waits WHERE raw_dur > 0 GROUP BY utid
),
-- The waited-for CPU is the CPU of the Running row that directly follows.
next_states AS MATERIALIZED (
  SELECT ts.id AS state_id,
    LEAD(ts.ts) OVER next_row AS next_ts,
    LEAD(ts.state) OVER next_row AS next_state,
    LEAD(ts.ucpu) OVER next_row AS next_ucpu
  FROM wait_bounds b JOIN thread_state ts ON ts.utid = b.utid AND ts.dur != 0
    AND ts.ts >= b.first_ts AND ts.ts <= b.last_end_ts
  WINDOW next_row AS (PARTITION BY ts.utid ORDER BY ts.ts, ts.id)
),
kept_segments AS MATERIALIZED (
  SELECT ws.*,
    CASE WHEN ws.raw_dur > 0 AND n.next_ts = ws.raw_start_ts + ws.raw_dur AND n.next_state = 'Running'
      THEN n.next_ucpu END AS ucpu
  FROM kept_waits ws LEFT JOIN next_states n ON n.state_id = ws.state_id
),
ii_wait AS MATERIALIZED (
  SELECT state_id AS id, seg_start_ts AS ts, seg_ns AS dur, ucpu
  FROM kept_segments WHERE ucpu IS NOT NULL AND seg_ns > 0
),
wait_span AS (
  SELECT MIN(ts) AS first_ts, MAX(ts + dur) AS last_end_ts FROM ii_wait
),
-- Sched slices of the waited-for CPUs within the span of the waits (which
-- lies inside the window), clipped to the window as
-- fragments/system_sched_spans.sql clips them. Read directly: that fragment
-- classifies topology for every slice of the window, which doubles the
-- cost of this Skill on a whole-trace window.
ii_sched AS MATERIALIZED (
  SELECT s.id, MAX(s.ts, w.window_start_ts) AS ts,
    MIN(s.end_ts, w.window_end_ts) - MAX(s.ts, w.window_start_ts) AS dur, s.ucpu
  FROM wait_span ws CROSS JOIN system_windows w
  JOIN (
    SELECT ss.id, ss.ts, ss.ucpu,
      CASE WHEN ss.dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE ss.ts + ss.dur END AS end_ts
    FROM sched_slice ss
    WHERE ss.dur != 0 AND ss.dur >= -1 AND ss.ucpu IN (SELECT DISTINCT ucpu FROM ii_wait)
  ) s ON s.ts < ws.last_end_ts AND s.end_ts > ws.first_ts
),
-- A sched slice whose thread is unknown counts as a task, never as idle.
overlaps AS (
  SELECT ks.window_id, ks.utid, ii.ucpu, ii.id_0 AS state_id, ii.dur AS overlap_ns,
    COALESCE(ot.is_idle, 0) = 1 AS is_idle,
    CASE WHEN COALESCE(ot.is_idle, 0) = 1 THEN NULL ELSE ss.utid END AS occupant_utid
  FROM _interval_intersect!((ii_wait, ii_sched), (ucpu)) ii
  JOIN sched_slice ss ON ss.id = ii.id_1
  LEFT JOIN thread ot ON ot.utid = ss.utid
  JOIN kept_segments ks ON ks.state_id = ii.id_0
  WHERE ii.dur > 0
),
attributed AS MATERIALIZED (
  SELECT window_id, utid, ucpu, is_idle, occupant_utid,
    SUM(overlap_ns) AS occupied_ns, COUNT(DISTINCT state_id) AS segment_count
  FROM overlaps GROUP BY window_id, utid, ucpu, is_idle, occupant_utid
),
cpu_waits AS (
  SELECT window_id, utid, ucpu, SUM(seg_ns) AS cpu_runnable_ns, COUNT(*) AS cpu_segment_count
  FROM kept_segments GROUP BY window_id, utid, ucpu
),
cpu_attributed AS (
  SELECT window_id, utid, ucpu, SUM(occupied_ns) AS attributed_ns,
    SUM(CASE WHEN is_idle THEN occupied_ns ELSE 0 END) AS idle_ns
  FROM attributed GROUP BY window_id, utid, ucpu
),
cpu_facts AS (
  SELECT cw.*, COALESCE(ca.idle_ns, 0) AS idle_ns,
    cw.cpu_runnable_ns - COALESCE(ca.attributed_ns, 0) AS unattributed_ns
  FROM cpu_waits cw LEFT JOIN cpu_attributed ca
    ON ca.window_id = cw.window_id AND ca.utid = cw.utid AND ca.ucpu = cw.ucpu
),
ranked_tasks AS (
  SELECT a.*, ROW_NUMBER() OVER (PARTITION BY a.window_id, a.utid, a.ucpu
    ORDER BY a.occupied_ns DESC, a.occupant_utid) AS occupant_rank
  FROM attributed a WHERE NOT a.is_idle
),
occupant_rows AS (
  SELECT window_id, utid, ucpu, 'task' AS occupant_kind, occupant_rank, occupant_utid,
    1 AS occupant_count, occupied_ns, segment_count
  FROM ranked_tasks WHERE occupant_rank <= ${max_occupants|5}
  UNION ALL
  SELECT window_id, utid, ucpu, 'other_tasks', ${max_occupants|5} + 1, NULL,
    COUNT(*), SUM(occupied_ns), NULL
  FROM ranked_tasks WHERE occupant_rank > ${max_occupants|5}
  GROUP BY window_id, utid, ucpu
  UNION ALL
  SELECT window_id, utid, ucpu, 'idle', NULL, NULL, NULL, occupied_ns, segment_count
  FROM attributed WHERE is_idle
  UNION ALL
  SELECT window_id, utid, ucpu, 'unattributed', NULL, NULL, NULL, unattributed_ns, NULL
  FROM cpu_facts WHERE unattributed_ns > 0
),
kernel_source AS (
  SELECT CASE WHEN EXISTS (SELECT 1 FROM process WHERE pid = 2)
    THEN 'linux_kernel_threads' ELSE 'kthreadd_unobserved' END AS kernel_thread_source
)
SELECT w.window_id, w.window_start_ts, w.window_end_ts, w.window_end_ts - w.window_start_ts AS window_dur_ns,
  k.upid, p.pid, p.name AS process_name, k.utid, t.tid, t.name AS thread_name, k.role,
  k.runnable_ns, k.targets_with_runnable, k.targets_omitted,
  cf.ucpu, c.cpu,
  CASE WHEN cf.ucpu IS NULL THEN 'eventual_run_cpu_unresolved' ELSE 'eventual_run_cpu' END AS cpu_basis,
  cf.cpu_runnable_ns, cf.cpu_segment_count, cf.idle_ns, cf.unattributed_ns,
  o.occupant_kind, o.occupant_rank, o.occupant_utid, ot.tid AS occupant_tid, ot.name AS occupant_thread_name,
  ot.upid AS occupant_upid, op.pid AS occupant_pid, op.name AS occupant_process_name,
  CASE WHEN o.occupant_kind <> 'task' OR ks.kernel_thread_source <> 'linux_kernel_threads' THEN NULL
    WHEN lk.utid IS NOT NULL THEN 1 ELSE 0 END AS occupant_is_kernel,
  o.occupant_count, o.occupied_ns, o.segment_count,
  1.0 * o.occupied_ns / NULLIF(cf.cpu_runnable_ns, 0) AS share_of_runnable,
  CASE WHEN o.occupant_kind = 'unattributed' THEN 'unavailable' ELSE 'observed' END AS occupancy_evidence,
  ks.kernel_thread_source,
  'same_cpu_occupancy_not_preemption_cause' AS evidence_scope
FROM system_windows w
JOIN kept_targets k ON k.window_id = w.window_id
JOIN thread t ON t.utid = k.utid JOIN process p ON p.upid = k.upid
JOIN cpu_facts cf ON cf.window_id = k.window_id AND cf.utid = k.utid
JOIN occupant_rows o ON o.window_id = cf.window_id AND o.utid = cf.utid AND o.ucpu IS cf.ucpu
LEFT JOIN cpu c ON c.id = cf.ucpu
LEFT JOIN thread ot ON ot.utid = o.occupant_utid
LEFT JOIN process op ON op.upid = ot.upid
LEFT JOIN linux_kernel_threads lk ON lk.utid = o.occupant_utid
CROSS JOIN kernel_source ks
ORDER BY w.window_id, CASE WHEN k.role = 'main' THEN 0 ELSE 1 END, k.runnable_ns DESC, k.utid,
  cf.cpu_runnable_ns DESC, cf.ucpu,
  CASE o.occupant_kind WHEN 'task' THEN 0 WHEN 'other_tasks' THEN 1 WHEN 'idle' THEN 2 ELSE 3 END,
  o.occupied_ns DESC, o.occupant_utid
