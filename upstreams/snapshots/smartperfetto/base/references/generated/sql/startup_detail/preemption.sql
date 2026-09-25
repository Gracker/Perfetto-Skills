-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: 33481081237e74c06b4dc8d1d96123519db58062a3214483d83a5ab46c43d287
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
target_switches AS (
  SELECT s.id as sched_id, s.utid, s.ucpu, s.cpu, s.priority,
    s.ts + s.dur as switch_ts, t.tid, t.name as thread_name,
    p.upid, p.pid, p.name as process_name
  FROM sched_slice s
  JOIN thread t ON s.utid = t.utid
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND s.end_state = 'R+' AND s.dur > 0
    AND s.ts + s.dur >= ${start_ts} AND s.ts + s.dur < ${end_ts}
)
SELECT s.sched_id, s.upid, s.pid, s.process_name, s.utid, s.tid, s.thread_name,
  s.ucpu, s.cpu, printf('%d', s.switch_ts) as switch_ts, s.priority,
  n.id as next_sched_id, n.utid as next_utid, nt.tid as next_tid,
  np.upid as next_upid, np.pid as next_pid, nt.is_idle as next_is_idle,
  CASE WHEN n.id IS NULL THEN 'successor_unavailable' WHEN nt.is_idle=1 THEN 'idle_not_competing_task'
    WHEN nt.is_idle=0 THEN 'scheduled_task_not_proven_wait_cause' ELSE 'idle_identity_unknown' END as next_role,
  nt.name as next_thread_name, np.name as next_process_name, n.priority as next_priority,
  w.id as wait_state_id,
  CASE WHEN w.dur >= 0 THEN ROUND((MIN(w.ts + w.dur, ${end_ts}) - MAX(w.ts, ${start_ts})) / 1e6, 3) ELSE NULL END as observed_wait_ms,
  CASE WHEN w.id IS NULL THEN 'missing_runnable_state'
    WHEN w.dur < 0 THEN 'incomplete_runnable_state'
    ELSE 'observed_runnable_preempted' END as wait_evidence,
  CASE WHEN n.id IS NULL THEN 'next_task_not_observed'
    ELSE 'exact_same_cpu_handoff_not_causal_duration' END as handoff_evidence,
  'not_recorded_in_sched_slice' as scheduling_policy_evidence
FROM target_switches s
LEFT JOIN sched_slice n ON n.ucpu = s.ucpu AND n.ts = s.switch_ts AND n.utid != s.utid
LEFT JOIN thread nt ON n.utid = nt.utid
LEFT JOIN process np ON nt.upid = np.upid
LEFT JOIN thread_state w ON w.utid = s.utid AND w.ts = s.switch_ts AND w.state = 'R+'
ORDER BY s.switch_ts, s.sched_id
