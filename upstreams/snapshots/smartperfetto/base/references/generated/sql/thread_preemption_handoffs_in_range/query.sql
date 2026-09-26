-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thread_preemption_handoffs_in_range.skill.yaml
-- Source SHA-256: 0d6aa446f7bc33de7c1867ce6be9c1042f9c3ba2c3da5fa80100744c268332ef
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
system_windows AS (
  SELECT 0 AS window_id, ${start_ts} AS window_start_ts, ${end_ts} AS window_end_ts
),
system_target_threads AS (
  SELECT w.window_id, p.upid, t.utid,
    CASE WHEN t.tid = p.pid THEN 'main' ELSE 'target' END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p
  JOIN thread t ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (${utid} IS NULL OR t.utid = ${utid})
)
SELECT w.window_id,w.window_start_ts,w.window_end_ts,w.window_end_ts-w.window_start_ts AS window_dur_ns,
  tt.upid,p.pid,p.name AS process_name,tt.utid,t.tid,t.name AS thread_name,tt.role,
  s.id AS sched_id,s.ucpu,s.cpu,s.ts AS raw_start_ts,s.dur AS raw_dur,s.ts+s.dur AS raw_end_ts,
  s.ts+s.dur AS switch_ts,s.priority,s.end_state,
  n.id AS peer_sched_id,n.utid AS peer_utid,pt.upid AS peer_upid,pt.tid AS peer_tid,
  pt.is_idle AS peer_is_idle,
  CASE WHEN n.id IS NULL THEN 'successor_unavailable'
    WHEN pt.is_idle=1 THEN 'idle_not_competing_task'
    WHEN pt.is_idle=0 THEN 'scheduled_task_not_proven_wait_cause'
    ELSE 'idle_identity_unknown' END AS peer_role,
  pt.name AS peer_thread_name,pp.name AS peer_process_name,n.ts AS peer_start_ts,
  n.dur AS peer_raw_dur,n.priority AS peer_priority,n.end_state AS peer_end_state,
  r.id AS runnable_state_id,r.ts AS runnable_start_ts,r.dur AS runnable_raw_dur,
  CASE WHEN r.dur=-1 THEN NULL ELSE r.ts+r.dur END AS runnable_end_ts,
  CASE WHEN r.id IS NOT NULL THEN MIN(CASE WHEN r.dur=-1 THEN (SELECT end_ts FROM trace_bounds)
    ELSE r.ts+r.dur END,w.window_end_ts)-r.ts END AS runnable_overlap_ns,
  CASE WHEN r.id IS NULL THEN NULL ELSE r.dur=-1 OR r.ts+r.dur>w.window_end_ts END AS runnable_right_censored,
  CASE WHEN n.id IS NULL THEN 'partial' ELSE 'observed' END AS handoff_evidence,
  'not_recorded_in_sched_slice' AS scheduling_policy_evidence,
  'direct_handoff_not_entire_wait_cause' AS evidence_scope
FROM system_windows w JOIN system_target_threads tt ON tt.window_id=w.window_id
JOIN thread t ON t.utid=tt.utid JOIN process p ON p.upid=tt.upid
JOIN sched_slice s ON s.utid=tt.utid AND s.dur>0 AND s.end_state='R+'
  AND s.ts+s.dur>=w.window_start_ts AND s.ts+s.dur<w.window_end_ts
LEFT JOIN sched_slice n ON n.ucpu=s.ucpu AND n.ts=s.ts+s.dur AND n.id!=s.id
LEFT JOIN thread pt ON pt.utid=n.utid LEFT JOIN process pp ON pp.upid=pt.upid
LEFT JOIN thread_state r ON r.utid=s.utid AND r.ts=s.ts+s.dur AND r.state='R+'
WHERE w.window_end_ts>w.window_start_ts
ORDER BY w.window_id,s.ts+s.dur,s.id
