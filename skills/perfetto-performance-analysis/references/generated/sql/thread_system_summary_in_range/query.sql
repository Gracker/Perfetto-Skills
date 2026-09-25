-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thread_system_summary_in_range.skill.yaml
-- Source SHA-256: 31a123f185507ef4507eccba97c35989dc3ab7c66b25bc6a4547216964c5cd8a
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- The pinned linux.cpu.frequency relation exposes the native ucpu after a
-- machine_id + cpu join. Use that identity rather than merging cpu ordinals.
-- Zero is a recorded counter value, not missing data or proof that hardware
-- actually executed instructions at zero frequency.
system_frequency_cpu_mapping AS (
  SELECT cpu,id AS ucpu,machine_id,1 AS mapping_count FROM cpu
),
system_cpu_frequency_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    f.id AS counter_id,f.track_id,f.cpu,m.ucpu,m.machine_id,f.freq AS freq_khz,
    f.ts AS raw_start_ts, f.dur AS raw_dur,
    CASE WHEN f.dur >= 0 THEN f.ts + f.dur END AS raw_end_ts,
    MAX(f.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(CASE WHEN f.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE f.ts + f.dur END, w.window_end_ts) AS clipped_end_ts,
    MIN(CASE WHEN f.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
      ELSE f.ts + f.dur END, w.window_end_ts) - MAX(f.ts, w.window_start_ts) AS dur_ns,
    f.dur = -1 AS is_unfinished,
    'linux.cpu.frequency:cpu_frequency_counters' AS frequency_source
  FROM system_windows w JOIN cpu_frequency_counters f
    ON f.ts < w.window_end_ts AND f.dur >= -1 AND f.dur != 0 AND f.freq >= 0
      AND CASE WHEN f.dur = -1 THEN (SELECT end_ts FROM trace_bounds)
        ELSE f.ts + f.dur END > w.window_start_ts
  JOIN system_frequency_cpu_mapping m ON m.ucpu=f.ucpu AND m.cpu=f.cpu
  WHERE w.window_end_ts > w.window_start_ts
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
),
states AS (
  SELECT window_id, utid, COUNT(*) AS state_count, SUM(dur_ns) AS state_covered_ns,
    SUM(CASE WHEN state='Running' THEN dur_ns ELSE 0 END) AS running_ns,
    SUM(CASE WHEN state IN ('R','R+') THEN dur_ns ELSE 0 END) AS runnable_ns,
    SUM(CASE WHEN state='R+' THEN dur_ns ELSE 0 END) AS runnable_preempted_ns,
    SUM(CASE WHEN state IN ('S','I') THEN dur_ns ELSE 0 END) AS sleeping_ns,
    SUM(CASE WHEN state IN ('D','DK') THEN dur_ns ELSE 0 END) AS uninterruptible_ns,
    SUM(CASE WHEN state NOT IN ('Running','R','R+','S','I','D','DK') THEN dur_ns ELSE 0 END) AS other_state_ns,
    SUM(CASE WHEN is_unfinished THEN dur_ns ELSE 0 END) AS unfinished_state_ns
  FROM system_thread_state_spans GROUP BY window_id,utid
),
sched AS (
  SELECT s.*, tt.role,
    LAG(s.ucpu) OVER (PARTITION BY s.window_id,s.utid ORDER BY s.raw_start_ts,s.sched_id) AS prev_ucpu
  FROM system_sched_spans s JOIN system_target_threads tt
    ON s.window_id=tt.window_id AND s.utid=tt.utid AND s.upid=tt.upid
),
placement AS (
  SELECT window_id,utid,COUNT(*) AS sched_count,SUM(dur_ns) AS sched_covered_ns,
    SUM(CASE WHEN core_type IN ('prime','big','medium') THEN dur_ns ELSE 0 END) AS big_running_ns,
    SUM(CASE WHEN core_type='little' THEN dur_ns ELSE 0 END) AS little_running_ns,
    SUM(CASE WHEN core_type NOT IN ('prime','big','medium','little') THEN dur_ns ELSE 0 END) AS unknown_running_ns,
    SUM(CASE WHEN topology_source='capacity_uniform_no_big_little' THEN dur_ns ELSE 0 END) AS homogeneous_running_ns,
    SUM(CASE WHEN topology_source IN ('capacity_unavailable','capacity_incomplete','cpu_identity_unavailable') THEN dur_ns ELSE 0 END) AS topology_missing_running_ns,
    GROUP_CONCAT(DISTINCT topology_source) AS topology_source,
    MIN(priority) AS priority_min,MAX(priority) AS priority_max,COUNT(DISTINCT priority) AS priority_value_count,
    SUM(CASE WHEN prev_ucpu IS NOT NULL AND prev_ucpu != ucpu THEN 1 ELSE 0 END) AS migrations
  FROM sched GROUP BY window_id,utid
),
frequency AS (
  SELECT s.window_id,s.utid,
    SUM(MIN(s.clipped_end_ts,f.clipped_end_ts)-MAX(s.clipped_start_ts,f.clipped_start_ts)) AS frequency_covered_ns,
    SUM(f.freq_khz*1.0*(MIN(s.clipped_end_ts,f.clipped_end_ts)-MAX(s.clipped_start_ts,f.clipped_start_ts))) /
      SUM(MIN(s.clipped_end_ts,f.clipped_end_ts)-MAX(s.clipped_start_ts,f.clipped_start_ts)) AS avg_freq_khz
  FROM sched s JOIN system_cpu_frequency_spans f
    ON f.window_id=s.window_id AND f.ucpu=s.ucpu
      AND f.clipped_start_ts<s.clipped_end_ts AND f.clipped_end_ts>s.clipped_start_ts
  GROUP BY s.window_id,s.utid
),
preemptions AS (
  SELECT w.window_id,s.utid,COUNT(*) AS preemption_count
  FROM system_windows w JOIN sched_slice s ON s.dur>0 AND s.end_state='R+'
    AND s.ts+s.dur>=w.window_start_ts AND s.ts+s.dur<w.window_end_ts
  JOIN system_target_threads tt ON tt.window_id=w.window_id AND tt.utid=s.utid
  GROUP BY w.window_id,s.utid
)
SELECT w.window_id,w.window_start_ts,w.window_end_ts,w.window_end_ts-w.window_start_ts AS window_dur_ns,
  tt.upid,p.pid,p.name AS process_name,tt.utid,t.tid,t.name AS thread_name,tt.role,
  COUNT(*) OVER (PARTITION BY w.window_id) AS total_target_threads,
  COALESCE(st.state_count,0) AS state_count,COALESCE(st.state_covered_ns,0) AS state_covered_ns,
  st.running_ns, st.runnable_ns, st.runnable_preempted_ns, st.sleeping_ns, st.uninterruptible_ns, st.other_state_ns, st.unfinished_state_ns,
  CASE WHEN st.state_count IS NULL THEN 'unavailable'
    WHEN st.state_covered_ns>w.window_end_ts-w.window_start_ts THEN 'unsupported'
    WHEN st.state_covered_ns<w.window_end_ts-w.window_start_ts THEN 'partial' ELSE 'observed' END AS state_evidence,
  pl.sched_covered_ns,pl.big_running_ns,pl.little_running_ns,pl.unknown_running_ns,
  pl.homogeneous_running_ns,pl.topology_missing_running_ns,pl.topology_source,
  CASE WHEN pl.sched_count IS NULL THEN 'unavailable'
    WHEN pl.topology_missing_running_ns=pl.sched_covered_ns THEN 'unknown_topology'
    WHEN pl.topology_missing_running_ns>0 THEN 'partial_topology'
    WHEN pl.homogeneous_running_ns=pl.sched_covered_ns THEN 'homogeneous_big_little_not_applicable'
    WHEN pl.homogeneous_running_ns>0 THEN 'mixed_topology_modes'
    ELSE 'heterogeneous_capacity' END AS placement_mode,
  CASE WHEN pl.sched_count IS NULL THEN 'unavailable'
    WHEN pl.topology_missing_running_ns>0 THEN 'partial' ELSE 'observed' END AS placement_evidence,
  f.avg_freq_khz,COALESCE(f.frequency_covered_ns,0) AS frequency_covered_ns,
  CASE WHEN f.frequency_covered_ns IS NULL THEN 'unavailable'
    WHEN f.frequency_covered_ns>pl.sched_covered_ns THEN 'unsupported'
    WHEN f.frequency_covered_ns<pl.sched_covered_ns THEN 'partial' ELSE 'observed' END AS frequency_evidence,
  pl.priority_min,pl.priority_max,COALESCE(pl.priority_value_count,0) AS priority_value_count,
  CASE WHEN pl.priority_value_count>0 THEN 'observed' ELSE 'unavailable' END AS priority_evidence,
  'not_recorded_in_sched_slice' AS scheduling_policy_evidence,
  'not_recorded_in_sched_slice' AS affinity_evidence,
  'not_recorded_in_sched_slice' AS cgroup_evidence,
  'not_recorded_in_sched_slice' AS uclamp_evidence,
  CASE WHEN st.state_count IS NULL AND pl.sched_count IS NULL AND pr.preemption_count IS NULL THEN NULL ELSE COALESCE(pr.preemption_count,0) END AS preemption_count,
  CASE WHEN st.state_count IS NULL THEN 'unavailable'
    WHEN st.state_covered_ns=w.window_end_ts-w.window_start_ts AND COALESCE(pl.sched_covered_ns,0)=st.running_ns THEN 'observed'
    ELSE 'partial' END AS preemption_evidence,
  pl.migrations,'task_observations_not_causal_attribution' AS evidence_scope
FROM system_windows w JOIN system_target_threads tt ON w.window_id=tt.window_id
JOIN thread t ON tt.utid=t.utid JOIN process p ON p.upid=tt.upid
LEFT JOIN states st ON st.window_id=w.window_id AND st.utid=tt.utid
LEFT JOIN placement pl ON pl.window_id=w.window_id AND pl.utid=tt.utid
LEFT JOIN frequency f ON f.window_id=w.window_id AND f.utid=tt.utid
LEFT JOIN preemptions pr ON pr.window_id=w.window_id AND pr.utid=tt.utid
WHERE w.window_end_ts>w.window_start_ts
ORDER BY w.window_id,CASE WHEN tt.role='main' THEN 0 ELSE 1 END,st.runnable_ns DESC,st.running_ns DESC,tt.utid
