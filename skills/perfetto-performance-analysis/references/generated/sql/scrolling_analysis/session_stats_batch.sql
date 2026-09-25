-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: b7ebca89bd8e31ada9de2d388e0e3cd9e257c8ef65e1c0e6862c167bc631da67
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

WITH
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
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
-- 1. VSync config (同 scroll_sessions)
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
-- 2. Session boundaries (同 scroll_sessions)
frame_gaps AS (
  SELECT
    a.ts, a.dur, a.upid,
    p.name as process_name,
    a.ts - LAG(a.ts + a.dur) OVER (PARTITION BY a.upid ORDER BY a.ts) as gap_ns
  FROM actual_frame_timeline_slice a
  JOIN effective_target_processes p ON a.upid = p.upid
  WHERE (
    ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
    OR p.name = '${package}'
    OR p.name GLOB '${package}:*'
  )
    AND p.name NOT LIKE '/system/%'
    -- With no target package the clause above accepts any process, and
    -- the system UI is the one most likely to be drawing while the target
    -- app draws nothing. Its frames are punctual, so they read back as
    -- flawless scrolling for an app that produced no frames at all: one
    -- device reported 31fps SystemUI frames as "优秀", another rated a
    -- 5-frame notification-shade window. Anyone analysing the system UI
    -- deliberately names it and keeps these rows.
    AND ('${package}' != '' OR p.name NOT LIKE 'com.android.systemui%')
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND a.dur > 0
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT *,
    CASE WHEN gap_ns IS NULL OR gap_ns > (SELECT vsync_period_ns * 6 FROM vsync_config) THEN 1 ELSE 0 END as new_session
  FROM frame_gaps
),
sessions_raw AS (
  SELECT *,
    SUM(new_session) OVER (PARTITION BY upid ORDER BY ts) as session_id
  FROM session_markers
),
session_bounds AS (
  SELECT
    upid, session_id, process_name,
    MIN(ts) as start_ts,
    MAX(ts + dur) as end_ts
  FROM sessions_raw
  GROUP BY upid, session_id
  HAVING COUNT(*) >= 10
    AND (MAX(ts + dur) - MIN(ts)) > 200000000
),
system_windows AS (
  SELECT CAST(upid AS TEXT)||':'||CAST(session_id AS TEXT) AS window_id,start_ts AS window_start_ts,end_ts AS window_end_ts
  FROM session_bounds
),
system_target_threads AS (
  SELECT w.window_id,sb.upid,t.utid,CASE WHEN t.tid=p.pid THEN 'MainThread' ELSE t.name END AS role
  FROM system_windows w JOIN session_bounds sb ON w.window_id=CAST(sb.upid AS TEXT)||':'||CAST(sb.session_id AS TEXT)
  JOIN effective_target_processes p ON p.upid=sb.upid JOIN thread t ON t.upid=sb.upid
  WHERE t.tid=p.pid OR t.name IN ('RenderThread','GPU completion','hwuiTask0','hwuiTask1')
),
thread_detail AS (
  SELECT sb.session_id,sb.process_name,s.upid,s.utid,s.role AS thread_name,s.state,
    COALESCE(ct.core_type,'unknown') AS core_type,s.dur_ns AS dur
  FROM system_thread_state_spans s JOIN session_bounds sb ON s.window_id=CAST(sb.upid AS TEXT)||':'||CAST(sb.session_id AS TEXT)
  LEFT JOIN system_cpu_topology ct ON ct.ucpu=s.ucpu
),
-- 4. 四象限聚合 (MainThread + RenderThread)
quadrant_agg AS (
  SELECT
    session_id, process_name, upid, utid,
    thread_name as thread,
    SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') THEN dur ELSE 0 END) as q1_ns,
    SUM(CASE WHEN state = 'Running' AND core_type = 'little' THEN dur ELSE 0 END) as q2_ns,
    SUM(CASE WHEN state IN ('R', 'R+') THEN dur ELSE 0 END) as q3_ns,
    SUM(CASE WHEN state IN ('D', 'DK') THEN dur ELSE 0 END) as q4a_ns,
    SUM(CASE WHEN state IN ('S', 'I') THEN dur ELSE 0 END) as q4b_ns,
    SUM(CASE WHEN state = 'Running' AND core_type = 'unknown' THEN dur ELSE 0 END) AS unknown_running_ns,
    SUM(dur) as total_ns
  FROM thread_detail
  WHERE thread_name IN ('MainThread', 'RenderThread')
  GROUP BY session_id, process_name, upid, utid, thread_name
),
-- 5. 大小核分布聚合 (所有出图线程, Running 状态)
core_aff_raw AS (
  SELECT
    session_id, process_name, upid, utid, thread_name, core_type,
    SUM(CASE WHEN state = 'Running' THEN dur ELSE 0 END) as run_dur_ns
  FROM thread_detail
  GROUP BY session_id, process_name, upid, utid, thread_name, core_type
  HAVING SUM(CASE WHEN state = 'Running' THEN dur ELSE 0 END) > 0
),
core_aff_with_pct AS (
  SELECT ca.*,
    ROUND(100.0 * ca.run_dur_ns / NULLIF(
      SUM(ca.run_dur_ns) OVER (PARTITION BY ca.session_id, ca.upid, ca.utid), 0
    ), 1) as pct
  FROM core_aff_raw ca
),
-- 6. CPU 频率聚合 (一次 counter 扫描)
cpu_freq_agg AS (
  SELECT sb.session_id,sb.process_name,sb.upid,COALESCE(ct.core_type,'unknown') AS core_type,
    COUNT(DISTINCT f.ucpu) AS num_cores,
    ROUND(SUM(f.freq_khz*1.0*f.dur_ns)/NULLIF(SUM(f.dur_ns),0)/1000,0) AS avg_freq_mhz,
    ROUND(MAX(f.freq_khz)/1000,0) AS max_freq_mhz,ROUND(MIN(f.freq_khz)/1000,0) AS min_freq_mhz,
    SUM(f.dur_ns) AS frequency_covered_ns
  FROM system_cpu_frequency_spans f JOIN session_bounds sb ON f.window_id=CAST(sb.upid AS TEXT)||':'||CAST(sb.session_id AS TEXT)
  LEFT JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  GROUP BY sb.session_id,sb.process_name,sb.upid,ct.core_type
)
-- 最终输出: 每个 session 一行, 3 个 JSON 列 + 匹配键
SELECT
  sb.upid,
  sb.session_id,
  sb.process_name,
  printf('%d', sb.start_ts) as start_ts,
  (SELECT json_group_array(json_object(
    'thread', sub.thread, 'upid', sub.upid, 'utid', sub.utid,
    'unknown_running_ms', ROUND(sub.unknown_running_ns / 1e6, 2),
    'q1_big_pct', ROUND(100.0 * sub.q1_ns / NULLIF(sub.total_ns, 0), 1),
    'q2_little_pct', ROUND(100.0 * sub.q2_ns / NULLIF(sub.total_ns, 0), 1),
    'q3_runnable_pct', ROUND(100.0 * sub.q3_ns / NULLIF(sub.total_ns, 0), 1),
    'q4a_io_pct', ROUND(100.0 * sub.q4a_ns / NULLIF(sub.total_ns, 0), 1),
    'q4b_sleep_pct', ROUND(100.0 * sub.q4b_ns / NULLIF(sub.total_ns, 0), 1),
    'total_ms', ROUND(sub.total_ns / 1e6, 1)
  )) FROM (
    SELECT * FROM quadrant_agg qa
    WHERE qa.session_id = sb.session_id AND qa.upid = sb.upid
    ORDER BY CASE qa.thread WHEN 'MainThread' THEN 1 ELSE 2 END
  ) sub) as quadrant_json,
  (SELECT json_group_array(json_object(
    'core_type', sub.core_type,
    'num_cores', sub.num_cores,
    'avg_freq_mhz', sub.avg_freq_mhz,
    'max_freq_mhz', sub.max_freq_mhz,
    'min_freq_mhz', sub.min_freq_mhz, 'frequency_covered_ns', sub.frequency_covered_ns
  )) FROM (
    SELECT * FROM cpu_freq_agg cf
    WHERE cf.session_id = sb.session_id AND cf.upid = sb.upid
    ORDER BY cf.max_freq_mhz DESC
  ) sub) as cpu_freq_json,
  (SELECT json_group_array(json_object(
    'thread_name', sub.thread_name, 'upid', sub.upid, 'utid', sub.utid,
    'core_type', sub.core_type,
    'run_ms', ROUND(sub.run_dur_ns / 1e6, 2),
    'pct', sub.pct
  )) FROM (
    SELECT * FROM core_aff_with_pct cap
    WHERE cap.session_id = sb.session_id AND cap.upid = sb.upid
    ORDER BY
      CASE cap.thread_name
        WHEN 'MainThread' THEN 1 WHEN 'RenderThread' THEN 2
        WHEN 'GPU completion' THEN 3 ELSE 4
      END, cap.run_dur_ns DESC
  ) sub) as core_affinity_json
FROM session_bounds sb
ORDER BY sb.start_ts
