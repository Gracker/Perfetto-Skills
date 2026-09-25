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
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Keep the process table available for global/peer joins. Only an explicitly
-- authored target relation consumes this trusted execution scope.
effective_target_processes AS (
  SELECT * FROM process
  WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}
)
,
-- 1. 视频解码活动检测：滑动期间是否有 MediaCodec/视频线程活跃
video_check AS (
  SELECT COUNT(*) as video_slice_count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE (t.name GLOB '*MediaCodec*' OR t.name GLOB '*CodecLooper*'
         OR t.name GLOB '*VideoDecoder*' OR t.name GLOB '*NuPlayer*'
         OR s.name GLOB '*queueVideoBuffer*' OR s.name GLOB '*onOutputBufferAvailable*')
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur < ${end_ts})
    AND s.dur > 100000
),
-- 2. 插帧帧数检测：frame_id = -1 通常是 OEM 插帧功能
interpolation_check AS (
  SELECT COUNT(*) as interpolation_frame_count
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
    AND COALESCE(a.display_frame_token, -999) = -1
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
system_windows AS (
  SELECT 0 AS window_id, COALESCE(${start_ts}, (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
),
cpufreq_tail_threshold AS (
  SELECT window_end_ts-2000000000 AS threshold FROM system_windows
),
thermal_check AS (
  SELECT ROUND(MAX(f.freq_khz)/1000,0) AS trace_peak_freq_mhz,
    ROUND(MIN(CASE WHEN f.clipped_end_ts>(SELECT threshold FROM cpufreq_tail_threshold) THEN f.freq_khz END)/1000,0) AS tail_min_freq_mhz
  FROM system_cpu_frequency_spans f JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  WHERE ct.core_type IN ('prime','big','medium')
),
-- 4. 非 App 大核 CPU 占用（后台干扰指标）
background_cpu AS (
  SELECT ROUND(100.0*SUM(CASE
    WHEN ((${__process_scope.upid} IS NOT NULL AND sched_span.upid<>${__process_scope.upid})
      OR (${__process_scope.upid} IS NULL AND '${package}'!='' AND NOT (p.name='${package}' OR p.name GLOB '${package}:*')))
    THEN sched_span.dur_ns ELSE 0 END)/NULLIF(SUM(sched_span.dur_ns),0),1) AS non_app_big_core_pct
  FROM system_sched_spans sched_span JOIN thread t ON t.utid=sched_span.utid JOIN process p ON p.upid=sched_span.upid
  WHERE sched_span.core_type IN ('prime','big','medium') AND t.is_idle=0
)
SELECT
  CASE WHEN COALESCE(v.video_slice_count, 0) > 20 THEN 1 ELSE 0 END as video_during_scroll,
  COALESCE(v.video_slice_count, 0) as video_slice_count,
  COALESCE(i.interpolation_frame_count, 0) as interpolation_frame_count,
  CASE WHEN COALESCE(i.interpolation_frame_count, 0) > 10 THEN 1 ELSE 0 END as interpolation_active,
  th.trace_peak_freq_mhz,
  th.tail_min_freq_mhz,
  -- Frequency decline is an observation; thermal causality needs independent temperature/throttle evidence.
  CASE WHEN th.trace_peak_freq_mhz > 0 AND th.tail_min_freq_mhz > 0
    AND th.tail_min_freq_mhz < th.trace_peak_freq_mhz * 0.70
    AND (SELECT threshold FROM cpufreq_tail_threshold) > COALESCE(${start_ts}, 0)
    THEN 1 WHEN th.trace_peak_freq_mhz IS NULL THEN NULL ELSE 0 END as frequency_decline_observed,
  NULL AS thermal_trending,
  'temperature_or_throttle_evidence_required' AS thermal_evidence,
  bg.non_app_big_core_pct as non_app_big_core_pct,
  CASE WHEN bg.non_app_big_core_pct > 60 THEN 1 WHEN bg.non_app_big_core_pct IS NULL THEN NULL ELSE 0 END as background_cpu_heavy
FROM video_check v, interpolation_check i, thermal_check th, background_cpu bg
