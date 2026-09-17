-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: 33481081237e74c06b4dc8d1d96123519db58062a3214483d83a5ab46c43d287
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

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
system_windows AS (SELECT 0 AS window_id,
  COALESCE(${start_ts},(SELECT start_ts FROM trace_bounds)) AS window_start_ts,
  COALESCE(${end_ts},(SELECT end_ts FROM trace_bounds)) AS window_end_ts),
system_target_threads AS (
  SELECT w.window_id,p.upid,t.utid,CASE WHEN t.tid=p.pid THEN 'main' ELSE 'target' END AS role
  FROM system_windows w CROSS JOIN effective_target_processes p JOIN thread t ON t.upid=p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}'='' OR p.name='${package}' OR p.name GLOB '${package}:*')
),
frequency AS (
 SELECT window_id,ucpu,SUM(dur_ns) AS coverage_ns,
 SUM(freq_khz*1.0*dur_ns)/SUM(dur_ns)/1000 AS avg_freq_mhz,
 MIN(freq_khz)/1000.0 AS min_freq_mhz,MAX(freq_khz)/1000.0 AS max_freq_mhz
 FROM system_cpu_frequency_spans GROUP BY window_id,ucpu
),
system_running AS (
 SELECT window_id,ucpu,SUM(dur_ns) AS coverage_ns,SUM(CASE WHEN is_idle=0 THEN dur_ns ELSE 0 END) AS busy_ns,
 SUM(CASE WHEN is_idle=1 THEN dur_ns ELSE 0 END) AS idle_ns,
 SUM(CASE WHEN is_idle IS NULL THEN dur_ns ELSE 0 END) AS idle_identity_unknown_ns
 FROM system_sched_spans GROUP BY window_id,ucpu
),
target_running AS (
 SELECT s.window_id,s.ucpu,s.utid,SUM(s.dur_ns) AS running_ns
 FROM system_sched_spans s JOIN system_target_threads tt ON tt.window_id=s.window_id AND tt.utid=s.utid AND tt.upid=s.upid
 GROUP BY s.window_id,s.ucpu,s.utid
)
SELECT tt.upid,p.pid,p.name AS process_name,tt.utid,t.tid,c.cpu,c.ucpu,w.window_start_ts,w.window_end_ts,
 c.core_type,c.topology_source,c.capacity,c.cluster_id,c.machine_id,
 ROUND(f.avg_freq_mhz,2) AS avg_freq_mhz,ROUND(f.min_freq_mhz,2) AS min_freq_mhz,ROUND(f.max_freq_mhz,2) AS max_freq_mhz,
 ROUND(COALESCE(f.coverage_ns,0)/1e6,2) AS freq_coverage_ms,
 ROUND(100.0*COALESCE(f.coverage_ns,0)/NULLIF(w.window_end_ts-w.window_start_ts,0),2) AS freq_coverage_pct,
 ROUND(COALESCE(s.coverage_ns,0)/1e6,2) AS sched_coverage_ms,
 ROUND(s.busy_ns/1e6,2) AS system_busy_ms,
 s.idle_ns,s.idle_identity_unknown_ns,
 CASE WHEN s.coverage_ns IS NULL THEN 'unavailable'
  WHEN s.coverage_ns>w.window_end_ts-w.window_start_ts THEN 'unsupported'
  WHEN s.idle_identity_unknown_ns>0 OR s.coverage_ns<w.window_end_ts-w.window_start_ts THEN 'partial' ELSE 'observed' END AS sched_evidence,
 ROUND(100.0*s.busy_ns/NULLIF(w.window_end_ts-w.window_start_ts,0),2) AS system_busy_pct,
 ROUND(CASE WHEN s.coverage_ns IS NULL THEN NULL ELSE COALESCE(r.running_ns,0)/1e6 END,2) AS target_main_running_ms,
 CASE WHEN m.mapping_count!=1 THEN 'unsupported' WHEN f.coverage_ns IS NULL THEN 'unavailable'
  WHEN f.coverage_ns<w.window_end_ts-w.window_start_ts THEN 'partial' ELSE 'observed' END AS frequency_evidence,
 'system_context_not_causal_attribution' AS evidence_scope
FROM system_target_threads tt JOIN system_windows w ON w.window_id=tt.window_id
JOIN thread t ON t.utid=tt.utid JOIN process p ON p.upid=tt.upid CROSS JOIN system_cpu_topology c
LEFT JOIN system_frequency_cpu_mapping m ON m.ucpu=c.ucpu
LEFT JOIN frequency f ON f.window_id=w.window_id AND f.ucpu=c.ucpu
LEFT JOIN system_running s ON s.window_id=w.window_id AND s.ucpu=c.ucpu
LEFT JOIN target_running r ON r.window_id=w.window_id AND r.ucpu=c.ucpu AND r.utid=tt.utid
WHERE tt.role='main' ORDER BY tt.upid,tt.utid,c.ucpu
