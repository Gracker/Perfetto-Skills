-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 0d32b714099786b1f04373b24b023fe8d99c6ce586baf33b2d38df56751b1044

-- 批量帧根因分类：对采样上限内的消费端真实掉帧执行简化版根因决策树
-- 与 jank_frame_detail 的 root_cause_summary 对齐的只有 direct-evidence（锁 / RT 同步）
-- 与限频（P4.5/P4.6，同一 frame binding fragment）两族，其余优先级各自不同
-- 区别：jank_frame_detail 是单帧深钻，此步骤是带覆盖率的批量分类
WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- The single read path for stdlib android_input_events. Skill contract:
-- event_action is the uppercase action without the Android prefix (MOVE, DOWN,
-- UP, CANCEL, ...). Newer trace processors report legacy atrace actions as
-- ACTION_MOVE/ACTION_DOWN/ACTION_UP; older ones reported MOVE/DOWN/UP. Every
-- other column passes through unchanged, NULL actions stay NULL. The column
-- list is the set every supported runtime has (v58.2 lacks frame_event_time);
-- keep it aligned with scrolling_analysis's input_data_fallback_view. NOT MATERIALIZED: consumers read it more than once
-- under their own filters, so SQLite should inline it rather than copy the table.
-- Frame association: the stdlib matches an event to the Choreographer#doFrame
-- its delivery overlaps (exact) or else to the next doFrame on the receiving
-- thread with no time bound (is_speculative_frame = 1), and derives
-- end_to_end_latency_dur from that frame. A speculative frame is a candidate,
-- not proof the event was consumed there, so frame linkage, presentation
-- latency and per-frame attribution read exact_frame_id /
-- exact_end_to_end_latency_dur. frame_association labels raw values for
-- display: none, exact, speculative, or unknown (a frame with no flag, which
-- is not treated as exact).
-- physical_event_key names the physical event a row delivers: every receiving
-- channel of one event shares it, so COUNT(DISTINCT physical_event_key) counts
-- events however many channels (app window, gesture monitors, dispatcher,
-- navigation bar) received each. Without an input_event_id the dispatch
-- timestamp stands in, which identifies only that one delivery. (The
-- physical_event_key of scene_input_facts.sql is a different, scene-local key
-- that also spans native motion/key events.)
-- window_owner is the stdlib's owner of the receiving channel,
-- str_split(str_split(event_channel, ' ', 1), '/', 0), spelled portably so the
-- SQLite fixtures run it: the package of a '<hash> <package>/<component>'
-- window. The stdlib credits an event_action only to a receiver whose name
-- equals that owner. Monitor, dispatcher, navigation-bar and wallpaper
-- channels never yield their receiver's name; nor do app windows titled
-- without '/' (PopupWindow:..). receiver_owns_window is 1 when the receiving
-- process owns the window: the exact name, or the name before ':' for
-- multi-process apps, whose delivery the stdlib cannot resolve (substr, not
-- GLOB: the owner is channel text).
android_input_events_normalized AS NOT MATERIALIZED (
  SELECT e.*,
    CASE WHEN e.window_owner != ''
      AND substr(e.process_name || ':', 1, length(e.window_owner) + 1) = e.window_owner || ':'
      THEN 1 ELSE 0 END AS receiver_owns_window
  FROM (
    SELECT
      dispatch_latency_dur, handling_latency_dur, ack_latency_dur,
      total_latency_dur, end_to_end_latency_dur,
      tid, thread_name, upid, pid, process_name,
      event_type,
      CASE WHEN event_action GLOB 'ACTION_*' THEN SUBSTR(event_action, 8)
        ELSE event_action END AS event_action,
      event_seq, event_channel, normalized_event_channel, input_event_id,
      read_time, dispatch_track_id, dispatch_ts, dispatch_dur,
      receive_ts, receive_dur, receive_track_id,
      frame_id, is_speculative_frame, event_time,
      CASE WHEN frame_id IS NOT NULL AND is_speculative_frame = 0
        THEN frame_id END AS exact_frame_id,
      CASE WHEN frame_id IS NOT NULL AND is_speculative_frame = 0
        THEN end_to_end_latency_dur END AS exact_end_to_end_latency_dur,
      CASE
        WHEN frame_id IS NULL THEN 'none'
        WHEN is_speculative_frame = 0 THEN 'exact'
        WHEN is_speculative_frame = 1 THEN 'speculative'
        ELSE 'unknown'
      END AS frame_association,
      COALESCE(input_event_id, 'dispatch:' || dispatch_ts) AS physical_event_key,
      -- Second word of the channel, cut at its first '/'.
      CASE WHEN instr(event_channel, ' ') > 0 THEN substr(
        replace(substr(event_channel, instr(event_channel, ' ') + 1), '/', ' '), 1,
        instr(replace(substr(event_channel, instr(event_channel, ' ') + 1), '/', ' ') || ' ', ' ') - 1)
      END AS window_owner
    FROM android_input_events
  ) AS e
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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Global CPU spans retain peer identity. Consumers join system_target_threads
-- explicitly; no global process-table replacement or synthetic switch boundary.
-- Capacity extrema require a complete machine population. A missing capacity
-- on any CPU prevents certifying which recorded CPU is fastest or smallest.
-- Big/little rollups over core_type follow the contract in
-- atomic/cpu_topology_view.skill.yaml (big group = prime/big/medium).
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

-- Requires, injected before it: system_sched_spans.sql (system_cpu_topology),
-- system_cpu_frequency_spans.sql.
-- Input defined by the consuming step:
--   system_windows(window_id, window_start_ts, window_end_ts)
--
-- Whether a window's big-core frequency was observed well enough to time a
-- frequency ramp. A ramp is "the first moment any big-tier CPU reached a high
-- frequency", so it is evidence only when every big-tier CPU's frequency is
-- known for the whole window: an unobserved CPU or stretch could have been at
-- high frequency, and an absent observation must not read as "never reached
-- high". frequency_spans drops NULL, negative and zero-length samples, so a
-- counter track that started before the window can still leave holes; the
-- check is the union of each CPU's valid clipped spans, not a span count or a
-- duration sum (one CPU may carry overlapping tracks).
--
-- freq_ramp_evidence:
--   machine_scope_ambiguous    CPUs of more than one machine: the window has
--                              no machine identity, so no single big tier
--   big_core_topology_unknown  no CPU is classified big/medium (capacity
--                              missing or uniform)
--   big_core_freq_incomplete   some big-tier CPU is not covered for the window
--   observed                   every big-tier CPU is covered for the window
-- Consumers time a ramp only for 'observed'; otherwise the ramp is NULL.
system_cpu_big_freq_spans AS (
  SELECT f.window_id,f.ucpu,f.window_start_ts,f.window_end_ts,f.clipped_start_ts,f.clipped_end_ts,
    MAX(f.clipped_end_ts) OVER (PARTITION BY f.window_id,f.ucpu ORDER BY f.clipped_start_ts,f.clipped_end_ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS covered_until
  FROM system_cpu_frequency_spans f JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  -- drops an unfinished sample that starts at or after the trace end (zero length)
  WHERE ct.core_type IN ('prime','big','medium') AND f.clipped_end_ts>f.clipped_start_ts
),
system_cpu_big_freq_cpu_coverage AS (
  SELECT window_id,ucpu
  FROM system_cpu_big_freq_spans
  GROUP BY window_id,ucpu
  HAVING MIN(clipped_start_ts)<=MIN(window_start_ts) AND MAX(clipped_end_ts)>=MAX(window_end_ts)
    AND SUM(CASE WHEN clipped_start_ts>covered_until THEN 1 ELSE 0 END)=0
),
system_cpu_big_freq_coverage AS (
  SELECT w.window_id,
    CASE
      WHEN (SELECT COUNT(DISTINCT COALESCE(machine_id,-1)) FROM system_cpu_topology)>1 THEN 'machine_scope_ambiguous'
      WHEN big.cpu_count=0 THEN 'big_core_topology_unknown'
      WHEN COALESCE(covered.cpu_count,0)<big.cpu_count THEN 'big_core_freq_incomplete'
      ELSE 'observed'
    END AS freq_ramp_evidence
  FROM system_windows w
  CROSS JOIN (SELECT COUNT(*) AS cpu_count FROM system_cpu_topology WHERE core_type IN ('prime','big','medium')) big
  LEFT JOIN (SELECT window_id,COUNT(*) AS cpu_count FROM system_cpu_big_freq_cpu_coverage GROUP BY window_id) covered
    ON covered.window_id=w.window_id
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
-- Fragment: vsync_config
-- Estimates VSync period using scoped then trace-wide VSYNC/FrameTimeline evidence.
-- The explicit 16.67ms default is used only when the trace has no usable timing evidence.
-- Snaps to nearest standard refresh rate (30/60/90/120/144/165 Hz) to avoid
-- half-period toggle contamination and jitter-induced miscalculation.
-- Params: ${start_ts}, ${end_ts}
vsync_ticks AS (
  SELECT c.ts, c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts} - 100000000)
    AND (${end_ts} IS NULL OR c.ts < ${end_ts} + 100000000)
),
trace_vsync_ticks AS (
  SELECT c.ts, c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
),
expected_frame_vsync AS (
  SELECT CAST(PERCENTILE(dur, 50) AS INTEGER) as period_ns
  FROM expected_frame_timeline_slice
  WHERE dur > 5000000 AND dur < 50000000
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
trace_expected_frame_vsync AS (
  SELECT CAST(PERCENTILE(dur, 50) AS INTEGER) as period_ns
  FROM expected_frame_timeline_slice
  WHERE dur > 5000000 AND dur < 50000000
),
raw_vsync_config AS (
  SELECT
    CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_ticks
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      (SELECT period_ns FROM expected_frame_vsync WHERE period_ns > 0),
      (SELECT PERCENTILE(interval_ns, 50)
       FROM trace_vsync_ticks
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      (SELECT period_ns FROM trace_expected_frame_vsync WHERE period_ns > 0),
      16666667
    ) AS INTEGER) as raw_ns,
    CASE
      WHEN (SELECT COUNT(*) FROM vsync_ticks WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0
        THEN CASE
          WHEN ${start_ts} IS NULL OR ${end_ts} IS NULL THEN 'trace_wide_vsync_counter'
          ELSE 'scoped_vsync_counter'
        END
      WHEN (SELECT period_ns FROM expected_frame_vsync WHERE period_ns > 0) IS NOT NULL
        THEN CASE
          WHEN ${start_ts} IS NULL OR ${end_ts} IS NULL THEN 'trace_wide_expected_frame'
          ELSE 'scoped_expected_frame'
        END
      WHEN (SELECT COUNT(*) FROM trace_vsync_ticks WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0
        THEN 'trace_wide_vsync_counter'
      WHEN (SELECT period_ns FROM trace_expected_frame_vsync WHERE period_ns > 0) IS NOT NULL
        THEN 'trace_wide_expected_frame'
      ELSE 'default_60hz_no_trace_timing'
    END as vsync_source
),
vsync_config AS (
  SELECT
    CASE
      WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
      WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
      WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
      WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
      WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
      WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
      ELSE raw_ns
    END AS vsync_period_ns,
    vsync_source
  FROM raw_vsync_config
)
,
-- Fragment: root_cause_sample_cap
-- Single source of truth for the per-session root-cause frame sample cap.
-- Both get_app_jank_frames (which truncates the frame list) and
-- batch_frame_root_cause (which reports eligible/analyzed coverage) must use
-- the same effective cap, otherwise reported coverage would not describe the
-- rows that were actually analyzed.
-- Unset, zero, and negative caps all normalize to the 200-frame default.
-- Params: ${max_frames_per_session}
root_cause_sample_config AS (
  SELECT CASE
    WHEN ${max_frames_per_session} IS NULL THEN 200
    WHEN CAST(${max_frames_per_session} AS INTEGER) <= 0 THEN 200
    ELSE CAST(${max_frames_per_session} AS INTEGER)
  END as root_cause_sample_limit_per_session
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- The windowed `system_cpu_freq_limit_spans` requires
-- fragments/system_sched_spans.sql to be injected FIRST: policy leader CPUs
-- are classified through its system_cpu_topology, so every CPU Skill shares
-- one big/little definition. The window-independent CTEs (raw samples, data
-- status, reference) read only cpu_counter_track and counter, so a data check
-- may inject this fragment alone.
--
-- Direct cpufreq policy limit evidence from the typed tracks emitted by the
-- ftrace event power/cpu_frequency_limits. `cpu_counter_track.cpu` carries the
-- cpufreq policy leader CPU, not every CPU governed by that policy.
--
-- A track's first sample is the first CHANGE observed, so the state before it
-- is unknown; it is never proof that the policy was unlimited. The per-policy
-- reference is the maximum max-limit observed in this trace and is explicitly
-- labelled `observed_max_limit_in_trace_not_hardware_max`: it cannot establish
-- the hardware or OPP-table maximum.
--
-- `raw_end_ts` is the unclipped end of the value a sample sets: the next
-- sample of the same track, or the trace end for the last one.
--
-- Validity is decided here and nowhere else: a sample whose value is <= 0 is
-- not a limit (`limit_value_valid = 0`). It never enters the reference, and the
-- span it opens is neither capped nor binding. Consumers show it only as a
-- data-quality fact. `prev_sample_*` describe the immediately preceding sample
-- of the same track; the direction of a change is derived from them once, in
-- system_cpu_freq_limit_episodes.sql (system_cpu_freq_limit_samples).
system_cpu_freq_limit_raw AS MATERIALIZED (
  SELECT x.*, COALESCE(x.next_ts, (SELECT end_ts FROM trace_bounds)) AS raw_end_ts
  FROM (
    SELECT t.id AS track_id, t.cpu AS policy_cpu,
      CASE WHEN t.type='cpu_max_frequency_limit' THEN 'max' ELSE 'min' END AS kind,
      c.id AS counter_id, c.ts, CAST(c.value AS INTEGER) AS limit_khz,
      CASE WHEN c.value > 0 THEN 1 ELSE 0 END AS limit_value_valid,
      CAST(LAG(c.value) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS INTEGER) AS prev_sample_limit_khz,
      LAG(CASE WHEN c.value > 0 THEN 1 ELSE 0 END) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS prev_sample_valid,
      LEAD(c.ts) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS next_ts
    FROM cpu_counter_track t JOIN counter c ON c.track_id = t.id
    WHERE t.type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')
  ) x
),
-- Whether this trace can answer a max-limit question at all. Track existence
-- is not enough: an empty max track, or one holding only invalid samples, is
-- `max_limit_samples_missing`; no max track (min-only or nothing) is
-- `max_limit_not_captured`. Every consumer gates max-limit analysis on
-- `has_max_limit_data` and reports a missing one with
-- `limit_evidence_classification` and `limit_evidence_missing_note`.
system_cpu_freq_limit_data_status AS (
  SELECT a.*,
    CASE WHEN a.valid_max_sample_count > 0 THEN 1 ELSE 0 END AS has_max_limit_data,
    CASE WHEN a.sample_count > 0 THEN 1 ELSE 0 END AS has_any_limit_sample,
    -- The session class for a trace that cannot answer at all; every other
    -- class comes from system_cpu_freq_limit_episode_verdicts.sql.
    CASE WHEN a.valid_max_sample_count > 0 THEN NULL ELSE 'LIMIT_EVIDENCE_MISSING' END
      AS limit_evidence_classification,
    CASE
      WHEN a.valid_max_sample_count > 0 THEN NULL
      WHEN a.max_limit_track_count = 0 THEN 'max_limit_not_captured'
      ELSE 'max_limit_samples_missing'
    END AS limit_evidence_missing_reason,
    CASE
      WHEN a.valid_max_sample_count > 0 THEN NULL
      WHEN a.max_limit_track_count = 0 THEN
        '没有 cpufreq policy 最大上限轨道（cpu_max_frequency_limit；只有下限轨道或完全没有限频轨道）：无法直接判断频率是否被限制。观测到的低频既可能是被限频，也可能只是负载下降或进入空闲 DVFS，没有限频事件时两者不可区分。请在采集配置的 ftrace_events 中加入 power/cpu_frequency_limits 后重新采集。'
      ELSE
        '有 cpufreq policy 最大上限轨道（cpu_max_frequency_limit），但没有有效的上限样本（轨道为空或只有 <= 0 的无效值）：无效值不是限频，无法据此判断频率是否被限制。请确认 power/cpu_frequency_limits 采集正常后重新采集。'
    END AS limit_evidence_missing_note
  FROM (
    SELECT
      (SELECT COUNT(*) FROM cpu_counter_track WHERE type = 'cpu_max_frequency_limit') AS max_limit_track_count,
      (SELECT COUNT(*) FROM cpu_counter_track WHERE type = 'cpu_min_frequency_limit') AS min_limit_track_count,
      COUNT(*) AS sample_count,
      COALESCE(SUM(CASE WHEN kind = 'max' AND limit_value_valid = 1 THEN 1 ELSE 0 END), 0) AS valid_max_sample_count,
      COALESCE(SUM(CASE WHEN kind = 'max' AND limit_value_valid = 0 THEN 1 ELSE 0 END), 0) AS invalid_max_sample_count,
      COALESCE(SUM(CASE WHEN kind = 'min' AND limit_value_valid = 0 THEN 1 ELSE 0 END), 0) AS invalid_min_sample_count
    FROM system_cpu_freq_limit_raw
  ) a
),
system_cpu_freq_limit_reference AS (
  SELECT policy_cpu,
    MAX(CASE WHEN kind='max' AND limit_value_valid = 1 THEN limit_khz END) AS reference_max_limit_khz,
    MIN(CASE WHEN kind='max' THEN ts END) AS first_max_sample_ts,
    MAX(CASE WHEN kind='max' THEN ts END) AS last_max_sample_ts,
    'observed_max_limit_in_trace_not_hardware_max' AS reference_basis
  FROM system_cpu_freq_limit_raw
  GROUP BY policy_cpu
),
system_cpu_freq_limit_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    r.track_id, r.policy_cpu, r.kind, r.counter_id,
    r.limit_khz, r.limit_value_valid,
    tp.ucpu, tp.machine_id, tp.capacity,
    COALESCE(tp.core_type, 'unknown') AS core_type,
    COALESCE(tp.topology_source, 'cpu_identity_unavailable') AS topology_source,
    r.ts AS raw_start_ts, r.raw_end_ts,
    MAX(r.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(r.raw_end_ts, w.window_end_ts) AS clipped_end_ts,
    MIN(r.raw_end_ts, w.window_end_ts) - MAX(r.ts, w.window_start_ts) AS dur_ns,
    r.ts < w.window_start_ts AS left_censored,
    r.next_ts IS NULL OR r.next_ts > w.window_end_ts AS right_censored,
    r.ts = ref.first_max_sample_ts AND r.kind='max' AS is_first_max_sample,
    r.ts = ref.last_max_sample_ts AND r.kind='max' AS is_last_max_sample,
    ref.reference_max_limit_khz, ref.reference_basis,
    'ftrace:power/cpu_frequency_limits' AS limit_source
  FROM system_windows w
  JOIN system_cpu_freq_limit_raw r
    ON r.ts < w.window_end_ts AND r.raw_end_ts > w.window_start_ts
  LEFT JOIN system_cpu_freq_limit_reference ref ON ref.policy_cpu = r.policy_cpu
  -- The event names the leader by its local cpu number. When several machines
  -- share that number the identity is ambiguous, so no topology is attached.
  LEFT JOIN system_cpu_topology tp ON tp.cpu = r.policy_cpu
    AND (SELECT COUNT(*) FROM cpu c2 WHERE c2.cpu = r.policy_cpu) = 1
  WHERE w.window_end_ts > w.window_start_ts
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Requires fragments/system_cpu_freq_limit_spans.sql to be injected FIRST and
-- system_windows(window_id, window_start_ts, window_end_ts) to exist.
--
-- This fragment owns the only rules that classify a limit SAMPLE: whether it
-- is capped, the direction of the change it records, and which value onset
-- it belongs to. Consumers read these CTEs; they never re-derive direction,
-- validity or capping.
--
-- A valid max-limit sample counts as capped when it sits below the per-policy
-- observed reference by more than ${episode_drop_pct|10} percent. Consecutive
-- capped spans separated by a gap shorter than ${merge_gap_ms|500} ms become
-- ONE episode: kernel governors re-write the limit every few tens of
-- milliseconds, so the raw event stream would otherwise report hundreds of
-- "episodes" for a single continuous mitigation.
--
-- Both thresholds are inputs. They bound what is reported, not what happened.
--
-- Direction is computed only against the immediately preceding sample of the
-- same track, and only when that sample is valid (contiguous). The first
-- sample of a track and the first valid value after an invalid one have
-- direction `unknown`: what came before them was not observed.
--
-- A VALUE ONSET is a valid sample whose value differs from the contiguous
-- previous value (or whose direction is unknown). cpufreq re-emits the max
-- limit on every policy update, including min-only boosts, so a re-write with
-- the same value is not an onset: it inherits the onset of the value in force.
system_cpu_freq_limit_samples AS MATERIALIZED (
  SELECT o.*,
    -- PR-B: the per-frame binding maps a binding span to its value onset by this id.
    FIRST_VALUE(o.counter_id) OVER (PARTITION BY o.track_id, o.onset_group ORDER BY o.ts, o.counter_id)
      AS value_onset_counter_id,
    FIRST_VALUE(o.ts) OVER (PARTITION BY o.track_id, o.onset_group ORDER BY o.ts, o.counter_id)
      AS value_onset_ts,
    MAX(o.raw_end_ts) OVER (PARTITION BY o.track_id, o.onset_group) AS value_end_ts
  FROM (
    SELECT d.*,
      SUM(CASE WHEN d.is_value_onset = 1 OR d.limit_value_valid = 0 THEN 1 ELSE 0 END) OVER (
        PARTITION BY d.track_id ORDER BY d.ts, d.counter_id ROWS UNBOUNDED PRECEDING
      ) AS onset_group
    FROM (
      SELECT r.track_id, r.policy_cpu, r.kind, r.counter_id, r.ts, r.raw_end_ts,
        r.limit_khz, r.limit_value_valid, r.prev_sample_limit_khz,
        CASE WHEN r.limit_value_valid = 1 AND r.prev_sample_valid = 1
          THEN r.prev_sample_limit_khz END AS prev_valid_limit_khz,
        CASE
          WHEN r.limit_value_valid = 0 THEN 'invalid_limit_sample'
          WHEN r.prev_sample_valid IS NULL THEN 'first_observed_sample'
          WHEN r.prev_sample_valid = 0 THEN 'onset_after_invalid_sample'
          ELSE 'contiguous_valid_previous'
        END AS direction_basis,
        CASE
          WHEN r.limit_value_valid = 0 OR r.prev_sample_valid IS NULL OR r.prev_sample_valid = 0
            THEN 'unknown'
          WHEN r.limit_khz < r.prev_sample_limit_khz THEN 'decreased'
          WHEN r.limit_khz > r.prev_sample_limit_khz THEN 'increased'
          ELSE 'unchanged'
        END AS value_change,
        CASE WHEN r.limit_value_valid = 1 AND NOT (
            COALESCE(r.prev_sample_valid, 0) = 1 AND r.limit_khz = r.prev_sample_limit_khz)
          THEN 1 ELSE 0 END AS is_value_onset,
        ref.reference_max_limit_khz, ref.reference_basis,
        CASE WHEN r.kind = 'max' AND r.limit_value_valid = 1 AND ref.reference_max_limit_khz > 0
            AND r.limit_khz < ref.reference_max_limit_khz * (1.0 - (${episode_drop_pct|10}) / 100.0)
          THEN 1 ELSE 0 END AS is_capped
      FROM system_cpu_freq_limit_raw r
      LEFT JOIN system_cpu_freq_limit_reference ref ON ref.policy_cpu = r.policy_cpu
    ) d
  ) o
),
-- Trace-wide episodes: the same drop and merge rules, grouped by policy only,
-- on unclipped sample spans. Their ids (`policy%d-tep%d`) and onsets do not
-- depend on any query window, so a window that cuts through an episode can
-- never manufacture an onset at its own start.
system_cpu_freq_limit_trace_episode_spans AS MATERIALIZED (
  SELECT g.*,
    printf('policy%d-tep%d', g.policy_cpu, g.trace_episode_seq) AS trace_episode_id
  FROM (
    SELECT m.*,
      SUM(CASE WHEN m.prev_capped_end_ts IS NULL
        OR m.ts - m.prev_capped_end_ts >= CAST((${merge_gap_ms|500}) * 1000000 AS INTEGER)
        THEN 1 ELSE 0 END) OVER (
        PARTITION BY m.policy_cpu ORDER BY m.ts, m.counter_id ROWS UNBOUNDED PRECEDING
      ) AS trace_episode_seq
    FROM (
      SELECT s.*,
        LAG(s.raw_end_ts) OVER (PARTITION BY s.policy_cpu ORDER BY s.ts, s.counter_id) AS prev_capped_end_ts
      FROM system_cpu_freq_limit_samples s
      WHERE s.kind = 'max' AND s.is_capped = 1 AND s.raw_end_ts > s.ts
    ) m
  ) g
),
-- The onset is observed only when the first capped sample records a change
-- from a contiguous valid value.
system_cpu_freq_limit_trace_episodes AS MATERIALIZED (
  SELECT f.trace_episode_id, f.policy_cpu, f.trace_episode_seq,
    MIN(f.ts) AS onset_ts,
    MAX(f.raw_end_ts) AS end_ts,
    MAX(CASE WHEN f.first_direction_basis = 'contiguous_valid_previous' THEN 1 ELSE 0 END) AS onset_observed,
    MAX(f.first_direction_basis) AS onset_basis
  FROM (
    SELECT e.*,
      FIRST_VALUE(e.direction_basis) OVER (PARTITION BY e.policy_cpu, e.trace_episode_seq ORDER BY e.ts, e.counter_id)
        AS first_direction_basis
    FROM system_cpu_freq_limit_trace_episode_spans e
  ) f
  GROUP BY f.trace_episode_id, f.policy_cpu, f.trace_episode_seq
),
-- One row per limit sample of every policy, inside an episode or not. Max
-- samples are trigger candidates; uncapped restorations and changes outside
-- episodes are events with a direction but no trigger verdict. Min limits
-- (floors) are policy actions too, but they never cap a frequency: they are
-- non-trigger facts, never in an episode, trigger class or rank.
system_cpu_freq_limit_events AS (
  SELECT s.track_id, s.policy_cpu, s.kind, s.counter_id, s.ts, s.raw_end_ts,
    s.limit_khz, s.limit_value_valid, s.prev_sample_limit_khz, s.prev_valid_limit_khz,
    CASE
      WHEN s.value_change NOT IN ('decreased', 'increased') THEN s.value_change
      WHEN s.kind = 'max' THEN CASE s.value_change WHEN 'decreased' THEN 'tightened' ELSE 'relaxed' END
      ELSE CASE s.value_change WHEN 'increased' THEN 'floor_raised' ELSE 'floor_lowered' END
    END AS direction,
    s.direction_basis,
    CASE WHEN s.value_change IN ('decreased', 'increased')
      THEN s.limit_khz - s.prev_valid_limit_khz END AS delta_khz,
    s.is_value_onset, s.value_onset_counter_id, s.value_onset_ts, s.value_end_ts,
    s.is_capped, s.reference_max_limit_khz, s.reference_basis,
    CASE WHEN tes.trace_episode_id IS NULL THEN 0 ELSE 1 END AS in_episode,
    tes.trace_episode_id,
    CASE s.kind WHEN 'max' THEN 'trigger_candidate' ELSE 'non_trigger_fact' END AS event_role
  FROM system_cpu_freq_limit_samples s
  LEFT JOIN system_cpu_freq_limit_trace_episode_spans tes ON tes.counter_id = s.counter_id
),
system_cpu_freq_limit_max_events AS MATERIALIZED (
  SELECT * FROM system_cpu_freq_limit_events WHERE kind = 'max'
),
-- Window-scoped episodes: the capped trace-episode spans that fall inside a
-- window, one row per (window, trace episode). `episode_id` keeps the
-- per-window numbering (`policy%d-ep%d`); `trace_episode_id`, `onset_ts` and
-- `onset_observed` identify the window-independent episode it belongs to.
system_cpu_freq_limit_capped_spans AS (
  SELECT s.*, tes.trace_episode_id, tes.trace_episode_seq
  FROM system_cpu_freq_limit_spans s
  JOIN system_cpu_freq_limit_trace_episode_spans tes ON tes.counter_id = s.counter_id
  WHERE s.kind = 'max' AND s.dur_ns > 0
),
system_cpu_freq_limit_episodes AS (
  SELECT
    g.window_id,
    g.policy_cpu,
    printf('policy%d-ep%d', g.policy_cpu,
      ROW_NUMBER() OVER (PARTITION BY g.window_id, g.policy_cpu ORDER BY g.episode_start_ts, g.trace_episode_seq))
      AS episode_id,
    g.trace_episode_id,
    te.onset_ts,
    te.onset_observed,
    te.onset_basis,
    te.end_ts AS trace_episode_end_ts,
    g.ucpu, g.machine_id, g.capacity, g.core_type, g.topology_source,
    g.episode_start_ts, g.episode_end_ts, g.episode_dur_ns,
    g.min_limit_khz, g.max_limit_khz_in_episode, g.reference_max_limit_khz, g.reference_basis,
    g.depth_pct, g.change_count,
    g.starts_at_data_start, g.ends_at_data_end,
    g.clipped_at_window_start, g.clipped_at_window_end,
    g.limit_source, g.evidence_status, g.evidence_scope
  FROM (
    SELECT c.window_id, c.policy_cpu, c.trace_episode_id, c.trace_episode_seq,
      MAX(c.ucpu) AS ucpu,
      MAX(c.machine_id) AS machine_id,
      MAX(c.capacity) AS capacity,
      MAX(c.core_type) AS core_type,
      MAX(c.topology_source) AS topology_source,
      MIN(c.clipped_start_ts) AS episode_start_ts,
      MAX(c.clipped_end_ts) AS episode_end_ts,
      MAX(c.clipped_end_ts) - MIN(c.clipped_start_ts) AS episode_dur_ns,
      MIN(c.limit_khz) AS min_limit_khz,
      MAX(c.limit_khz) AS max_limit_khz_in_episode,
      MAX(c.reference_max_limit_khz) AS reference_max_limit_khz,
      MAX(c.reference_basis) AS reference_basis,
      ROUND(100.0 * (MAX(c.reference_max_limit_khz) - MIN(c.limit_khz))
        / NULLIF(MAX(c.reference_max_limit_khz), 0), 1) AS depth_pct,
      COUNT(*) AS change_count,
      MAX(CASE WHEN c.is_first_max_sample THEN 1 ELSE 0 END) AS starts_at_data_start,
      MAX(CASE WHEN c.is_last_max_sample THEN 1 ELSE 0 END) AS ends_at_data_end,
      MAX(CASE WHEN c.left_censored THEN 1 ELSE 0 END) AS clipped_at_window_start,
      MAX(CASE WHEN c.right_censored THEN 1 ELSE 0 END) AS clipped_at_window_end,
      MAX(c.limit_source) AS limit_source,
      CASE WHEN MAX(CASE WHEN c.is_first_max_sample THEN 1 ELSE 0 END) = 1
          OR MAX(CASE WHEN c.is_last_max_sample THEN 1 ELSE 0 END) = 1
          OR MAX(CASE WHEN c.left_censored THEN 1 ELSE 0 END) = 1
          OR MAX(CASE WHEN c.right_censored THEN 1 ELSE 0 END) = 1
        THEN 'partial' ELSE 'observed' END AS evidence_status,
      'observation_not_causal' AS evidence_scope
    FROM system_cpu_freq_limit_capped_spans c
    GROUP BY c.window_id, c.policy_cpu, c.trace_episode_id, c.trace_episode_seq
  ) g
  JOIN system_cpu_freq_limit_trace_episodes te ON te.trace_episode_id = g.trace_episode_id
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Kernel cooling-device state from the ftrace event thermal/cdev_update, typed
-- as counter_track.type='cooling_device_counter'. The value is the requested
-- target state; 0 means the device is not cooling.
--
-- `cdev_kind_hint` is derived from the device NAME and is a hint only: the
-- kernel does not export the governed subsystem through this event, so the
-- hint cannot establish which policy a cooling device actually throttles;
-- thermal_cdev_policy_association.sql ties a device to a policy from
-- transition/limit-change timing instead.
-- Absence of these tracks is not absence of throttling. Platforms whose
-- userspace thermal daemon writes the cpufreq sysfs limits directly emit no
-- cdev_update at all.
--
-- Device identity is resolved once per track, not once per sample: the
-- `linux_device` dimension lookup is a correlated subquery and dominated the
-- per-sample scan when it sat there.
thermal_cooling_devices AS (
  SELECT ct.id AS cdev_track_id,
    COALESCE(
      (SELECT a.string_value FROM args a
       WHERE a.arg_set_id = ct.dimension_arg_set_id AND a.key = 'linux_device'),
      ct.name
    ) AS cdev_name,
    CASE
      WHEN LOWER(ct.name) GLOB '*cpufreq*' THEN 'cpufreq'
      WHEN LOWER(ct.name) GLOB '*gpufreq*' THEN 'gpufreq'
      ELSE 'other'
    END AS cdev_kind_hint,
    'name_pattern_hint_not_kernel_declared_target' AS cdev_kind_basis
  FROM counter_track ct
  WHERE ct.type = 'cooling_device_counter'
),
-- `direction` compares a sample with the previous one of the same device; it
-- is the only cooling direction rule, shared by the windowed spans and by
-- thermal_cdev_policy_association.sql. `raw_end_ts` is the unclipped end of
-- the state a sample sets.
thermal_cooling_raw AS MATERIALIZED (
  SELECT x.*,
    CASE
      WHEN x.prev_state IS NULL THEN 'first_observed_sample'
      WHEN x.state > x.prev_state THEN 'tightened'
      WHEN x.state < x.prev_state THEN 'relaxed'
      ELSE 'unchanged'
    END AS direction,
    COALESCE(x.next_ts, (SELECT end_ts FROM trace_bounds)) AS raw_end_ts
  FROM (
    SELECT c.track_id AS cdev_track_id,
      c.id AS counter_id, c.ts, CAST(c.value AS INTEGER) AS state,
      CAST(LAG(c.value) OVER (PARTITION BY c.track_id ORDER BY c.ts, c.id) AS INTEGER) AS prev_state,
      LEAD(c.ts) OVER (PARTITION BY c.track_id ORDER BY c.ts, c.id) AS next_ts
    FROM counter c
    WHERE c.track_id IN (SELECT cdev_track_id FROM thermal_cooling_devices)
  ) x
),
thermal_cooling_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    d.cdev_track_id, d.cdev_name, d.cdev_kind_hint, d.cdev_kind_basis,
    r.counter_id, r.ts, r.state, r.prev_state, r.direction,
    r.state > 0 AS is_cooling_active,
    r.ts AS raw_start_ts, r.raw_end_ts,
    MAX(r.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(r.raw_end_ts, w.window_end_ts) AS clipped_end_ts,
    MIN(r.raw_end_ts, w.window_end_ts) - MAX(r.ts, w.window_start_ts) AS dur_ns,
    r.ts < w.window_start_ts AS left_censored,
    r.next_ts IS NULL OR r.next_ts > w.window_end_ts AS right_censored,
    'ftrace:thermal/cdev_update' AS cooling_source
  FROM system_windows w
  JOIN thermal_cooling_raw r
    ON r.ts < w.window_end_ts AND r.raw_end_ts > w.window_start_ts
  JOIN thermal_cooling_devices d ON d.cdev_track_id = r.cdev_track_id
  WHERE w.window_end_ts > w.window_start_ts
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Requires, injected in this order: system_cpu_freq_limit_spans.sql,
-- system_cpu_freq_limit_episodes.sql, thermal_cooling_spans.sql. Window
-- independent: it reads only the raw cooling samples and the trace-wide
-- max-limit events, never system_windows.
-- Inputs: ${cdev_policy_pair_ms|1}, ${cdev_policy_min_transitions|3},
-- ${cdev_policy_min_pair_pct|80}.
--
-- Which cpufreq policy a kernel cooling device governs is not declared by any
-- trace event: thermal/cdev_update records only the device name and its
-- target state, and a name such as `thermal-cpufreq-2` is a hint, not a
-- binding. What a trace does record is timing. When the kernel applies a
-- cooling step through cpufreq, the policy's max limit changes right AFTER the
-- cooling transition (tens to hundreds of microseconds on Pixel). This
-- fragment ties a cooling device to a policy only from that evidence.
--
--   transition   a cooling sample whose state differs from the previous one;
--                every transition is counted once (distinct transitions);
--   limit change a valid max-limit sample whose value differs from the
--                contiguous previous valid value (direction tightened/relaxed);
--   pair         FORWARD only: the limit change follows the transition by
--                0..cdev_policy_pair_ms. Each transition is matched to at most
--                one limit change per policy, the first one after it, so a
--                burst of limit updates never counts twice;
--   concordant   cooling tightens while the limit drops, or relaxes while it
--                rises.
--
-- A device is tied to policy P only when it has at least
-- cdev_policy_min_transitions transitions, at least cdev_policy_min_pair_pct %
-- of them pair with P, at least that share of those pairs are concordant, and
-- exactly one policy qualifies. The device name and `cdev_kind_hint` never
-- enter any branch.
thermal_cooling_transitions AS MATERIALIZED (
  SELECT r.cdev_track_id, r.counter_id, r.ts, r.state, r.prev_state, r.direction AS cooling_direction
  FROM thermal_cooling_raw r
  WHERE r.direction IN ('tightened', 'relaxed')
),
thermal_cooling_transition_counts AS (
  SELECT cdev_track_id, COUNT(*) AS transition_count
  FROM thermal_cooling_transitions GROUP BY cdev_track_id
),
-- Coverage is defined by sources that can attribute a limit WRITE. Only a
-- cooling device that actually transitioned can be forward-paired with a
-- limit change; temperature tracks and thermal-daemon names are hints and
-- never establish coverage. `cooling_track_count` only says which devices a
-- cooling overview can list.
thermal_cooling_transition_coverage AS (
  SELECT
    (SELECT COUNT(*) FROM thermal_cooling_devices) AS cooling_track_count,
    EXISTS (SELECT 1 FROM thermal_cooling_transitions) AS cooling_transition_coverage
),
thermal_cdev_limit_forward_pairs AS MATERIALIZED (
  SELECT p.cdev_track_id, p.transition_counter_id, p.transition_ts, p.cooling_direction,
    p.policy_cpu, p.limit_counter_id, p.limit_ts, p.limit_direction,
    p.limit_ts - p.transition_ts AS lead_ns,
    p.cooling_direction = p.limit_direction AS concordant
  FROM (
    SELECT t.cdev_track_id, t.counter_id AS transition_counter_id, t.ts AS transition_ts,
      t.cooling_direction,
      l.policy_cpu, l.counter_id AS limit_counter_id, l.ts AS limit_ts, l.direction AS limit_direction,
      ROW_NUMBER() OVER (PARTITION BY t.counter_id, l.policy_cpu ORDER BY l.ts, l.counter_id) AS pair_rank
    FROM thermal_cooling_transitions t
    JOIN system_cpu_freq_limit_max_events l
      ON l.direction IN ('tightened', 'relaxed')
      AND l.ts >= t.ts
      AND l.ts <= t.ts + CAST((${cdev_policy_pair_ms|1}) * 1000000 AS INTEGER)
  ) p
  WHERE p.pair_rank = 1
),
thermal_cdev_policy_pair_scores AS (
  SELECT sc.*,
    CASE WHEN sc.transition_count >= (${cdev_policy_min_transitions|3})
        AND sc.matched_transitions * 100.0 >= (${cdev_policy_min_pair_pct|80}) * sc.transition_count
        AND sc.concordant_pairs * 100.0 >= (${cdev_policy_min_pair_pct|80}) * sc.matched_transitions
      THEN 1 ELSE 0 END AS qualifies
  FROM (
    SELECT p.cdev_track_id, p.policy_cpu, tc.transition_count,
      COUNT(*) AS matched_transitions,
      SUM(p.concordant) AS concordant_pairs
    FROM thermal_cdev_limit_forward_pairs p
    JOIN thermal_cooling_transition_counts tc ON tc.cdev_track_id = p.cdev_track_id
    GROUP BY p.cdev_track_id, p.policy_cpu, tc.transition_count
  ) sc
),
thermal_cdev_policy_association AS (
  SELECT d.cdev_track_id, d.cdev_name,
    COALESCE(tc.transition_count, 0) AS transition_count,
    CASE WHEN q.qualified_policy_count = 1 THEN q.qualified_policy_cpu END AS associated_policy_cpu,
    CASE
      WHEN COALESCE(tc.transition_count, 0) < (${cdev_policy_min_transitions|3}) THEN 'insufficient_transitions'
      WHEN COALESCE(q.qualified_policy_count, 0) = 0 THEN 'no_policy_limit_pairing'
      WHEN q.qualified_policy_count > 1 THEN 'ambiguous_multiple_policies'
      ELSE 'paired_with_policy_limit_changes'
    END AS association_status,
    'cdev_transition_to_policy_limit_change_pairing' AS association_basis
  FROM thermal_cooling_devices d
  LEFT JOIN thermal_cooling_transition_counts tc ON tc.cdev_track_id = d.cdev_track_id
  LEFT JOIN (
    SELECT cdev_track_id,
      SUM(qualifies) AS qualified_policy_count,
      MAX(CASE WHEN qualifies = 1 THEN policy_cpu END) AS qualified_policy_cpu
    FROM thermal_cdev_policy_pair_scores
    GROUP BY cdev_track_id
  ) q ON q.cdev_track_id = d.cdev_track_id
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Discovery vocabulary for thermal / performance-policy signals on Android.
--
-- These rows are HINTS FOR EXPLORATION, never evidence. A name match says a
-- track, slice or thread is worth inspecting with execute_sql; it does not say
-- the component caused anything, nor that its semantics match the name. Vendor
-- atrace counters are unversioned, undocumented and differ per SoC and per OEM
-- build, so the product must not encode their meaning as truth.
--
-- Consumers lowercase both the subject and the pattern before GLOB, so the
-- match is case-insensitive. `exclude_pattern` removes known false friends
-- (e.g. the meminfo CommitLimit counter for the generic `*limit*` probe).
-- `rank_hint` orders candidates for presentation only: 1 is the most specific.
thermal_signal_signatures AS (
  SELECT '*thermal-engine*' AS pattern, NULL AS exclude_pattern, 'thermal_daemon' AS signature_kind,
    'process_or_thread' AS match_target, 'qualcomm' AS platform_hint, 1 AS rank_hint,
    'Qualcomm userspace thermal daemon; writes cpufreq sysfs limits directly' AS note
  UNION ALL SELECT '*thermal-service*', NULL, 'thermal_daemon', 'process_or_thread', 'android_hal', 1,
    'Android thermal HAL service process (vendor implementation varies)'
  UNION ALL SELECT '*thermalext*', NULL, 'thermal_daemon', 'process_or_thread', 'oem', 1,
    'OEM/app-vendor thermal extension service'
  UNION ALL SELECT 'mi_thermald*', NULL, 'thermal_daemon', 'process_or_thread', 'xiaomi', 1,
    'Xiaomi thermal daemon'
  UNION ALL SELECT 'thermal_manager*', NULL, 'thermal_daemon', 'process_or_thread', 'oem', 1,
    'OEM thermal manager daemon'
  UNION ALL SELECT '*mtk*thermal*', NULL, 'thermal_daemon', 'process_or_thread', 'mediatek', 1,
    'MediaTek thermal component (unverified on this repository''s trace corpus)'
  UNION ALL SELECT 'thermal_*', NULL, 'thermal_kernel_thread', 'process_or_thread', 'kernel', 1,
    'Kernel thermal zone worker thread (e.g. thermal_BIG); polls a zone, does not prove mitigation'
  UNION ALL SELECT '*perfservice*', NULL, 'perf_policy_daemon', 'process_or_thread', 'oem', 2,
    'OEM performance policy service; may change frequency limits for non-thermal reasons'
  UNION ALL SELECT '*powerhal*', NULL, 'perf_policy_daemon', 'process_or_thread', 'android_hal', 2,
    'Power HAL; hints and boosts are not thermal mitigation'
  UNION ALL SELECT '*power-service*', NULL, 'perf_policy_daemon', 'process_or_thread', 'android_hal', 2,
    'Power HAL service process'
  UNION ALL SELECT '*perf2-hal*', NULL, 'perf_policy_daemon', 'process_or_thread', 'oem', 2,
    'OEM perf HAL variant'
  UNION ALL SELECT '*bperf*', NULL, 'perf_policy_daemon', 'process_or_thread', 'oem', 2,
    'OEM boost/perf daemon variant'
  UNION ALL SELECT '*cooling*', NULL, 'cooling_signal', 'counter_or_slice', 'generic', 1,
    'Cooling device naming; prefer the typed cooling_device_counter track'
  UNION ALL SELECT '*cdev*', NULL, 'cooling_signal', 'counter_or_slice', 'generic', 1,
    'Cooling device abbreviation used by vendor atrace counters'
  UNION ALL SELECT '*throttl*', NULL, 'throttle_signal', 'counter_or_slice', 'generic', 1,
    'Explicit throttling naming; semantics are vendor defined'
  UNION ALL SELECT '*mitigat*', NULL, 'throttle_signal', 'counter_or_slice', 'generic', 1,
    'Mitigation naming used by several vendor thermal stacks'
  UNION ALL SELECT '*therm*', NULL, 'thermal_signal', 'counter_or_slice', 'generic', 2,
    'Any thermal-named track or slice; also matches app and activity names'
  UNION ALL SELECT '*ceiling*', NULL, 'limit_request_signal', 'counter_or_slice', 'generic', 2,
    'Upper-bound request naming (e.g. cdev_ceiling)'
  UNION ALL SELECT '*floor*', NULL, 'limit_request_signal', 'counter_or_slice', 'generic', 2,
    'Lower-bound request naming (e.g. cdev_floor)'
  UNION ALL SELECT '*_request*', NULL, 'limit_request_signal', 'counter_or_slice', 'generic', 2,
    'Vendor limit-request counters (e.g. pid_request, hardlimit_request, final_request)'
  UNION ALL SELECT '*hint*', NULL, 'perf_hint_signal', 'counter_or_slice', 'generic', 3,
    'Performance/thermal hint counters; a hint is a request, not an applied limit'
  UNION ALL SELECT '*ppm*', NULL, 'perf_policy_signal', 'counter_or_slice', 'mediatek', 3,
    'MediaTek PPM (performance power management) naming'
  UNION ALL SELECT '*limit*', '*commit*limit*', 'limit_request_signal', 'counter_or_slice', 'generic', 3,
    'Generic limit naming; the meminfo CommitLimit counter is excluded as a false friend'
  -- Non-CPU heat producers. Presence of these processes in a window is a
  -- reminder that CPU work is not the only thermal input; it is not a claim
  -- that they heated the device.
  UNION ALL SELECT '*camera*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Camera stack; sustained capture is a well known non-CPU heat source'
  UNION ALL SELECT '*mediacodec*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Hardware codec service; encode/decode load is not visible as CPU time'
  UNION ALL SELECT '*mediaserver*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 2,
    'Media server process'
  UNION ALL SELECT '*modem*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Modem-side service; radio activity heats the SoC without CPU time'
  UNION ALL SELECT '*ril*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 2,
    'Radio interface layer'
  UNION ALL SELECT '*cnss*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'qualcomm', 2,
    'Qualcomm connectivity subsystem daemon'
  UNION ALL SELECT '*dsp*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 2,
    'DSP (adsp/cdsp/slpi) services; offloaded compute is not CPU time'
  UNION ALL SELECT '*charg*', NULL, 'non_cpu_heat_hint', 'non_cpu_heat_process', 'generic', 1,
    'Charging service; charging is a direct heat source independent of workload'
)
,
-- Threads whose own or process name matches a process_or_thread signature,
-- one row per thread with its most specific pattern. Perf-policy daemons are
-- included here (they are candidates for NON-thermal limiting) and filtered
-- out of thermal_daemon_threads below. Consumers that need this in several
-- steps recompute it per step; it is not materialised by the engine.
thermal_signal_threads AS (
  SELECT utid, thread_name, process_name, pattern, signature_kind, platform_hint, rank_hint
  FROM (
    SELECT t.utid, COALESCE(t.name, '') AS thread_name, COALESCE(p.name, '') AS process_name,
      sig.pattern, sig.signature_kind, sig.platform_hint, sig.rank_hint,
      ROW_NUMBER() OVER (PARTITION BY t.utid ORDER BY sig.rank_hint, sig.pattern) AS rn
    FROM thread t
    LEFT JOIN process p ON p.upid = t.upid
    JOIN thermal_signal_signatures sig ON sig.match_target = 'process_or_thread'
      AND (LOWER(COALESCE(t.name, '')) GLOB sig.pattern
        OR LOWER(COALESCE(p.name, '')) GLOB sig.pattern)
  ) WHERE rn = 1
),
thermal_daemon_threads AS (
  SELECT utid FROM thermal_signal_threads
  WHERE signature_kind IN ('thermal_daemon', 'thermal_kernel_thread')
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Requires, injected in this order: system_sched_spans.sql,
-- system_cpu_freq_limit_spans.sql,
-- system_cpu_freq_limit_episodes.sql, thermal_cooling_spans.sql,
-- thermal_cdev_policy_association.sql, thermal_signal_signatures.sql.
-- Inputs: ${who_window_ms|2000}, ${cooling_coincidence_ms|50}, plus the
-- association inputs.
--
-- This is the ONLY place that decides what triggered a frequency limit. No
-- consumer keeps its own ladder, rank mapping, default class or class prose:
-- windowed Skills read the window-scoped rows (per-episode verdicts and the
-- window summary with its per-class episode counts, `is_confirmed` and
-- `class_note`), session facts read the trace-wide summary, and a per-frame
-- consumer reads the verdict of the value onset that wrote the limit in force
-- for it.
--
-- The unit of classification is the VALUE ONSET (system_cpu_freq_limit_samples):
-- every change of a policy's max-limit value inside a capped trace episode. An
-- episode, a window and the trace are summarised from their onsets: the best
-- (lowest) rank wins and `onset_trigger_mix` keeps the per-class counts, so a
-- mixed episode reads "confirmed for N of M limit changes", never "confirmed".
--
-- Onset ladder, first match wins:
--   direction unknown   first observed sample / first valid value after an
--                       invalid sample: the write time was not observed. Rank
--                       5, evaluated before any activity tier so co-occurring
--                       activity can never upgrade an unobservable onset.
--   relaxed             the limit rose (still capped). Neutral, never causal.
--   paired tightening   the limit dropped 0..cdev_policy_pair_ms AFTER a
--                       tightening transition of a cooling device tied to this
--                       policy (first-match forward pair). The only rank 1.
--   daemon              a thermal daemon ran in the who_window_ms before the
--                       write. A candidate, never a confirmation.
--   tied background     a tied cooling device was active while the value was
--                       in force, or changed state near the write without
--                       being its forward pair.
--   untied activity     only cooling devices not tied to this policy showed
--                       activity.
--   no evidence         cooling transitions were captured in this trace but
--                       none relates to the write (observed absence), or no
--                       cooling transition exists at all (not captured). Neither
--                       is a claim that the trigger was non-thermal.
system_cpu_freq_limit_trigger_classes AS (
  SELECT 1 AS trigger_class_rank, 'THERMAL_LIMIT_CONFIRMED' AS trigger_class, 'onset' AS class_scope, 1 AS is_confirmed,
    '限频值的写入紧跟在与该 policy 时序关联的内核散热设备升档之后（前向配对、同向）：这次收紧由内核热控施加。' AS class_note
  UNION ALL SELECT 2, 'THERMAL_DAEMON_SUSPECTED', 'onset', 0,
    '限频收紧前的归因窗口内有名字匹配温控签名的守护进程在运行：用户态温控是候选触发方，尚未证明因果；这类守护进程在未限频时也会运行。'
  UNION ALL SELECT 3, 'THERMAL_COOLING_BACKGROUND', 'onset', 0,
    '与该 policy 时序关联的散热设备在限频值生效期间处于非零档位或在写入附近换档，但没有与这次写入前向配对的升档：只是并存的背景热控候选，不能确认是施加者。'
  UNION ALL SELECT 4, 'THERMAL_COOLING_UNASSOCIATED', 'onset', 0,
    '限频值生效期间只有未与该 policy 关联的散热设备有活动：时序证据没有把它们与这个 policy 绑定，不能算作这次限频的施加者。'
  UNION ALL SELECT 5, 'LIMIT_ONSET_UNKNOWN', 'onset', 0,
    '限频值的写入时刻不可观测（轨道首样本，或紧跟在无效样本之后）：只报告受限时长与影响，不判断触发方，也不能写成非热限频。'
  UNION ALL SELECT 6, 'NO_THERMAL_EVIDENCE_OBSERVED', 'onset', 0,
    '本 trace 采集到了散热设备档位变化，但这次收紧既没有关联散热设备的配对或活动，也没有温控守护进程活动：未观测到热证据，但这不证明触发方是非热的。'
  UNION ALL SELECT 7, 'THERMAL_EVIDENCE_NOT_CAPTURED', 'onset', 0,
    '本 trace 没有任何散热设备档位变化，无法把这次限频写入归因到内核热控；温度或守护进程名只能算线索。触发方无法判定，需要补采 thermal/cdev_update。'
  UNION ALL SELECT 8, 'LIMIT_RELAXED', 'onset', 0,
    '上限被放宽（仍低于参考上限）：放宽不是限频的原因，不参与热证据判定；之前的收紧才是受限的来源。'
  UNION ALL SELECT NULL, 'NO_LIMIT_EPISODE', 'session', 0,
    '有有效的最大上限样本，但范围内没有超过阈值的限频区段。'
  UNION ALL SELECT NULL, 'LIMIT_EVIDENCE_MISSING', 'session', 0,
    '没有有效的最大上限样本（未采集 power/cpu_frequency_limits，或上限轨道为空/只有无效样本）：无法判断是否发生限频。'
),
system_cpu_freq_limit_onset_verdict_classes AS (
  SELECT 'thermal_cooling_device_confirmed' AS onset_verdict, 1 AS trigger_class_rank
  UNION ALL SELECT 'userspace_thermal_daemon_active_before_limit', 2
  UNION ALL SELECT 'policy_cooling_active_background', 3
  UNION ALL SELECT 'cooling_activity_policy_unassociated', 4
  UNION ALL SELECT 'onset_unknown_capped_at_data_start', 5
  UNION ALL SELECT 'onset_after_invalid_sample', 5
  UNION ALL SELECT 'limit_changed_no_thermal_evidence', 6
  UNION ALL SELECT 'thermal_evidence_not_captured', 7
  UNION ALL SELECT 'limit_relaxed', 8
),
_flv_onsets AS MATERIALIZED (
  SELECT e.trace_episode_id, e.policy_cpu, e.counter_id, e.ts, e.value_end_ts,
    e.limit_khz, e.prev_valid_limit_khz, e.direction, e.direction_basis,
    e.reference_max_limit_khz
  FROM system_cpu_freq_limit_max_events e
  WHERE e.is_value_onset = 1 AND e.in_episode = 1
),
_flv_tied AS MATERIALIZED (
  SELECT cdev_track_id, cdev_name, associated_policy_cpu AS policy_cpu
  FROM thermal_cdev_policy_association
  WHERE association_status = 'paired_with_policy_limit_changes'
),
_flv_active_cooling AS MATERIALIZED (
  SELECT r.cdev_track_id, r.ts, r.raw_end_ts AS end_ts
  FROM thermal_cooling_raw r
  WHERE r.state > 0
),
_flv_pairing AS (
  SELECT o.counter_id,
    MAX(CASE WHEN p.cooling_direction = 'tightened' THEN 1 ELSE 0 END) AS paired_tightening,
    MAX(CASE WHEN p.cooling_direction = 'relaxed' THEN 1 ELSE 0 END) AS paired_relaxing,
    MIN(CASE WHEN p.cooling_direction = 'tightened' THEN td.cdev_name END) AS paired_cdev_name,
    MIN(CASE WHEN p.cooling_direction = 'tightened' THEN p.lead_ns END) AS pair_lead_ns
  FROM _flv_onsets o
  JOIN thermal_cdev_limit_forward_pairs p ON p.limit_counter_id = o.counter_id
  JOIN _flv_tied td ON td.cdev_track_id = p.cdev_track_id AND td.policy_cpu = o.policy_cpu
  WHERE o.direction = 'tightened'
  GROUP BY o.counter_id
),
-- Activity tiers are evaluated only for tightening onsets that no tied
-- cooling transition applied; everything else is already decided.
_flv_open_onsets AS MATERIALIZED (
  SELECT o.* FROM _flv_onsets o
  LEFT JOIN _flv_pairing pa ON pa.counter_id = o.counter_id
  WHERE o.direction = 'tightened' AND COALESCE(pa.paired_tightening, 0) = 0
),
_flv_tied_nearby AS (
  SELECT o.counter_id,
    MAX(CASE WHEN t.ts > o.ts THEN 1 ELSE 0 END) AS tied_transition_after,
    MAX(CASE WHEN t.ts <= o.ts THEN 1 ELSE 0 END) AS tied_transition_before
  FROM _flv_open_onsets o
  JOIN _flv_tied td ON td.policy_cpu = o.policy_cpu
  JOIN thermal_cooling_transitions t ON t.cdev_track_id = td.cdev_track_id
    AND t.ts >= o.ts - CAST(${cooling_coincidence_ms|50} * 1000000 AS INTEGER)
    AND t.ts <= o.ts + CAST(${cooling_coincidence_ms|50} * 1000000 AS INTEGER)
  GROUP BY o.counter_id
),
_flv_cooling_activity AS (
  SELECT o.counter_id,
    MAX(CASE WHEN td.cdev_track_id IS NOT NULL THEN 1 ELSE 0 END) AS tied_active,
    MAX(CASE WHEN td.cdev_track_id IS NULL THEN 1 ELSE 0 END) AS untied_active
  FROM _flv_open_onsets o
  JOIN _flv_active_cooling a ON a.ts < o.value_end_ts AND a.end_ts > o.ts
  LEFT JOIN _flv_tied td ON td.cdev_track_id = a.cdev_track_id AND td.policy_cpu = o.policy_cpu
  GROUP BY o.counter_id
),
_flv_untied_transitions AS (
  SELECT o.counter_id, 1 AS untied_transition
  FROM _flv_open_onsets o
  JOIN thermal_cooling_transitions t
    ON t.ts >= o.ts - CAST(${cooling_coincidence_ms|50} * 1000000 AS INTEGER)
    AND t.ts < o.value_end_ts
  LEFT JOIN _flv_tied td ON td.cdev_track_id = t.cdev_track_id AND td.policy_cpu = o.policy_cpu
  WHERE td.cdev_track_id IS NULL
  GROUP BY o.counter_id
),
_flv_daemon_slices AS MATERIALIZED (
  SELECT s.ts, s.ts + s.dur AS end_ts
  FROM sched_slice s
  WHERE s.dur > 0 AND s.utid IN (SELECT utid FROM thermal_daemon_threads)
),
_flv_daemon AS (
  SELECT o.counter_id, COUNT(*) AS daemon_slices
  FROM _flv_open_onsets o
  JOIN _flv_daemon_slices d
    ON d.ts < o.ts AND d.end_ts > o.ts - CAST(${who_window_ms|2000} * 1000000 AS INTEGER)
  GROUP BY o.counter_id
),
system_cpu_freq_limit_onset_verdicts AS MATERIALIZED (
  SELECT v.*, vc.trigger_class_rank, c.trigger_class, c.is_confirmed, c.class_note
  FROM (
    SELECT f.trace_episode_id, f.policy_cpu, f.counter_id, f.onset_ts, f.value_end_ts,
      f.limit_khz, f.prev_valid_limit_khz, f.direction, f.direction_basis, f.reference_max_limit_khz,
      f.paired_tightening, f.paired_cdev_name, f.pair_lead_ns, f.daemon_slices,
      f.tied_active AS tied_cooling_active, f.untied_activity AS untied_cooling_activity,
      f.cooling_transition_coverage,
      CASE
        WHEN f.direction = 'unknown' AND f.direction_basis = 'onset_after_invalid_sample'
          THEN 'onset_after_invalid_sample'
        WHEN f.direction = 'unknown' THEN 'onset_unknown_capped_at_data_start'
        WHEN f.direction = 'relaxed' THEN 'limit_relaxed'
        WHEN f.paired_tightening = 1 THEN 'thermal_cooling_device_confirmed'
        WHEN f.daemon_slices > 0 THEN 'userspace_thermal_daemon_active_before_limit'
        WHEN f.paired_relaxing = 1 OR f.tied_after = 1 OR f.tied_before = 1 OR f.tied_active = 1
          THEN 'policy_cooling_active_background'
        WHEN f.untied_activity = 1 THEN 'cooling_activity_policy_unassociated'
        WHEN f.cooling_transition_coverage = 1 THEN 'limit_changed_no_thermal_evidence'
        ELSE 'thermal_evidence_not_captured'
      END AS onset_verdict,
      -- The cooling side alone, for frame-level readers: why a capped value
      -- is or is not attributed to a tied cooling device. Independent of the
      -- daemon tier.
      CASE
        WHEN f.direction = 'unknown' AND f.direction_basis = 'onset_after_invalid_sample'
          THEN 'onset_after_invalid_sample'
        WHEN f.direction = 'unknown' THEN 'onset_unobserved'
        WHEN f.direction = 'relaxed' THEN 'cap_value_set_by_relaxation'
        WHEN f.paired_tightening = 1 THEN 'limit_set_by_paired_policy_cooling_transition'
        WHEN f.paired_relaxing = 1 THEN 'discordant_cooling_pair'
        WHEN f.tied_after = 1 THEN 'cooling_follows_limit_change'
        WHEN f.tied_before = 1 THEN 'policy_cooling_not_paired_with_this_onset'
        WHEN f.tied_active = 1 THEN 'policy_cooling_active_limit_set_elsewhere'
        WHEN f.untied_activity = 1 THEN 'cooling_unassociated_with_policy'
        WHEN f.cooling_transition_coverage = 1 THEN 'no_cooling_evidence'
        ELSE 'cooling_track_unavailable'
      END AS cooling_basis,
      'observation_not_causal' AS evidence_scope
    FROM (
      SELECT o.trace_episode_id, o.policy_cpu, o.counter_id, o.ts AS onset_ts, o.value_end_ts,
        o.limit_khz, o.prev_valid_limit_khz, o.direction, o.direction_basis, o.reference_max_limit_khz,
        COALESCE(pa.paired_tightening, 0) AS paired_tightening,
        COALESCE(pa.paired_relaxing, 0) AS paired_relaxing,
        pa.paired_cdev_name, pa.pair_lead_ns,
        COALESCE(nb.tied_transition_after, 0) AS tied_after,
        COALESCE(nb.tied_transition_before, 0) AS tied_before,
        COALESCE(ca.tied_active, 0) AS tied_active,
        COALESCE(ca.untied_active, 0) OR COALESCE(ut.untied_transition, 0) AS untied_activity,
        COALESCE(dm.daemon_slices, 0) AS daemon_slices,
        cov.cooling_transition_coverage
      FROM _flv_onsets o
      CROSS JOIN thermal_cooling_transition_coverage cov
      LEFT JOIN _flv_pairing pa ON pa.counter_id = o.counter_id
      LEFT JOIN _flv_tied_nearby nb ON nb.counter_id = o.counter_id
      LEFT JOIN _flv_cooling_activity ca ON ca.counter_id = o.counter_id
      LEFT JOIN _flv_untied_transitions ut ON ut.counter_id = o.counter_id
      LEFT JOIN _flv_daemon dm ON dm.counter_id = o.counter_id
    ) f
  ) v
  JOIN system_cpu_freq_limit_onset_verdict_classes vc ON vc.onset_verdict = v.onset_verdict
  JOIN system_cpu_freq_limit_trigger_classes c ON c.trigger_class_rank = vc.trigger_class_rank
),
-- Scopes over which onsets are summarised. Window scopes keep only onsets
-- whose value is in force inside the window (including the onset before the
-- window that set the value in force at its start) and never cite a later
-- onset. The trace scope covers every onset and is labelled trace-wide.
_flv_window_onsets AS (
  SELECT e.window_id, e.episode_id, ov.counter_id
  FROM system_cpu_freq_limit_episodes e
  JOIN system_windows w ON w.window_id = e.window_id
  JOIN system_cpu_freq_limit_onset_verdicts ov ON ov.trace_episode_id = e.trace_episode_id
    AND ov.onset_ts < w.window_end_ts AND ov.value_end_ts > w.window_start_ts
),
_flv_scoped AS MATERIALIZED (
  SELECT k.scope, k.window_id, k.scope_key, ov.*
  FROM (
    SELECT 'window_episode' AS scope, window_id, episode_id AS scope_key, counter_id FROM _flv_window_onsets
    UNION ALL
    SELECT 'window', window_id, CAST(window_id AS TEXT), counter_id FROM _flv_window_onsets
    UNION ALL
    SELECT 'trace', NULL, 'trace', counter_id FROM system_cpu_freq_limit_onset_verdicts
  ) k
  JOIN system_cpu_freq_limit_onset_verdicts ov ON ov.counter_id = k.counter_id
),
-- Window-scoped onset rows of each window episode: what an episode detail
-- lists, with the same verdicts the episode summary is built from.
system_cpu_freq_limit_window_onset_verdicts AS (
  SELECT * FROM _flv_scoped WHERE scope = 'window_episode'
),
-- One row per scope, onsets or not: every window episode, every window and
-- the trace.
_flv_scope_keys AS (
  SELECT 'window_episode' AS scope, window_id, episode_id AS scope_key FROM system_cpu_freq_limit_episodes
  UNION ALL
  SELECT 'window', window_id, CAST(window_id AS TEXT) FROM system_windows
  UNION ALL
  SELECT 'trace', NULL, 'trace'
),
_flv_scope_summary AS MATERIALIZED (
  SELECT k.scope, k.window_id, k.scope_key,
    COALESCE(r.onset_count, 0) AS onset_count,
    COALESCE(r.causal_onset_count, 0) AS causal_onset_count,
    COALESCE(r.confirmed_onset_count, 0) AS confirmed_onset_count,
    COALESCE(r.relaxed_onset_count, 0) AS relaxed_onset_count,
    r.trigger_class_rank, c.trigger_class, c.is_confirmed, c.class_note,
    b.onset_verdict AS best_onset_verdict, b.onset_ts AS best_onset_ts,
    b.cooling_basis AS best_cooling_basis, b.paired_cdev_name AS best_paired_cdev_name,
    m.onset_trigger_mix
  FROM _flv_scope_keys k
  LEFT JOIN (
    SELECT scope, window_id, scope_key,
      COUNT(*) AS onset_count,
      SUM(CASE WHEN trigger_class <> 'LIMIT_RELAXED' THEN 1 ELSE 0 END) AS causal_onset_count,
      SUM(is_confirmed) AS confirmed_onset_count,
      SUM(CASE WHEN trigger_class = 'LIMIT_RELAXED' THEN 1 ELSE 0 END) AS relaxed_onset_count,
      MIN(trigger_class_rank) AS trigger_class_rank
    FROM _flv_scoped
    GROUP BY scope, window_id, scope_key
  ) r ON r.scope = k.scope AND r.window_id IS k.window_id AND r.scope_key = k.scope_key
  LEFT JOIN system_cpu_freq_limit_trigger_classes c ON c.trigger_class_rank = r.trigger_class_rank
  LEFT JOIN (
    SELECT * FROM (
      SELECT s.scope, s.window_id, s.scope_key, s.onset_verdict, s.onset_ts, s.cooling_basis, s.paired_cdev_name,
        ROW_NUMBER() OVER (PARTITION BY s.scope, s.window_id, s.scope_key
          ORDER BY s.trigger_class_rank, s.onset_ts, s.counter_id) AS rn
      FROM _flv_scoped s
    ) WHERE rn = 1
  ) b ON b.scope = k.scope AND b.window_id IS k.window_id AND b.scope_key = k.scope_key
  LEFT JOIN (
    SELECT scope, window_id, scope_key,
      GROUP_CONCAT(trigger_class || ':' || n, ',' ORDER BY trigger_class_rank) AS onset_trigger_mix
    FROM (
      SELECT scope, window_id, scope_key, trigger_class, trigger_class_rank, COUNT(*) AS n
      FROM _flv_scoped
      GROUP BY scope, window_id, scope_key, trigger_class, trigger_class_rank
    )
    GROUP BY scope, window_id, scope_key
  ) m ON m.scope = k.scope AND m.window_id IS k.window_id AND m.scope_key = k.scope_key
),
_flv_policy_ties AS (
  SELECT policy_cpu, COUNT(*) AS tied_cooling_device_count, MIN(cdev_name) AS tied_cooling_device
  FROM _flv_tied GROUP BY policy_cpu
),
-- Window-scoped: one row per window episode. `episode_verdict` is the verdict
-- of the best in-window onset; `onset_trigger_mix` lists every in-window
-- onset class with its count. Materialized because both consumers and the
-- window summary's episode facts read it.
system_cpu_freq_limit_episode_verdicts AS MATERIALIZED (
  SELECT e.*,
    ss.onset_count, ss.causal_onset_count, ss.confirmed_onset_count, ss.relaxed_onset_count,
    ss.trigger_class_rank, ss.trigger_class, COALESCE(ss.is_confirmed, 0) AS is_confirmed, ss.class_note,
    ss.best_onset_verdict AS episode_verdict,
    ss.best_onset_ts, ss.best_cooling_basis, ss.best_paired_cdev_name,
    ss.onset_trigger_mix,
    COALESCE(pt.tied_cooling_device_count, 0) AS tied_cooling_device_count,
    pt.tied_cooling_device,
    CASE WHEN pt.tied_cooling_device_count IS NULL THEN 'no_cooling_device_tied_to_policy'
      ELSE 'tied_by_transition_limit_pairing' END AS cooling_policy_association,
    'window_scoped' AS verdict_scope
  FROM system_cpu_freq_limit_episodes e
  JOIN _flv_scope_summary ss ON ss.scope = 'window_episode'
    AND ss.window_id = e.window_id AND ss.scope_key = e.episode_id
  LEFT JOIN _flv_policy_ties pt ON pt.policy_cpu = e.policy_cpu
),
-- Per-window episode facts, counted by each episode's own class: what a
-- windowed consumer reports next to the window classification.
_flv_window_episode_facts AS (
  SELECT window_id,
    COUNT(*) AS episode_count,
    COUNT(DISTINCT policy_cpu) AS policy_count,
    ROUND(MAX(depth_pct), 1) AS deepest_depth_pct,
    MAX(episode_dur_ns) AS longest_episode_ns,
    SUM(is_confirmed) AS confirmed_episode_count,
    SUM(CASE WHEN trigger_class = 'THERMAL_DAEMON_SUSPECTED' THEN 1 ELSE 0 END) AS daemon_suspected_episode_count,
    SUM(CASE WHEN trigger_class = 'THERMAL_COOLING_BACKGROUND' THEN 1 ELSE 0 END) AS cooling_background_episode_count,
    SUM(CASE WHEN trigger_class = 'THERMAL_COOLING_UNASSOCIATED' THEN 1 ELSE 0 END) AS cooling_unassociated_episode_count,
    SUM(CASE WHEN onset_observed = 0 THEN 1 ELSE 0 END) AS onset_unknown_episode_count
  FROM system_cpu_freq_limit_episode_verdicts
  GROUP BY window_id
),
-- Distinct cooling devices tied to any policy the window's episodes touch: two
-- policies each tied to its own device are two devices, and one policy with
-- several episodes is counted once.
_flv_window_tied_devices AS (
  SELECT wp.window_id, COUNT(DISTINCT t.cdev_name) AS tied_cooling_device_count
  FROM (SELECT DISTINCT window_id, policy_cpu FROM system_cpu_freq_limit_episode_verdicts) wp
  JOIN _flv_tied t ON t.policy_cpu = wp.policy_cpu
  GROUP BY wp.window_id
),
-- Classification per query window. NO_LIMIT_EPISODE and
-- LIMIT_EVIDENCE_MISSING are the only values that do not come from an onset;
-- an episode whose onsets are all unobservable reads LIMIT_ONSET_UNKNOWN,
-- never a non-thermal trigger. `is_confirmed` and `class_note` belong to the
-- window classification.
system_cpu_freq_limit_window_summary AS (
  SELECT s.*, c.is_confirmed, c.class_note
  FROM (
    SELECT w.window_id, w.window_start_ts, w.window_end_ts,
      COALESCE(ef.episode_count, 0) AS episode_count,
      COALESCE(ef.policy_count, 0) AS policy_count,
      ef.deepest_depth_pct, ef.longest_episode_ns,
      COALESCE(ef.confirmed_episode_count, 0) AS confirmed_episode_count,
      COALESCE(ef.daemon_suspected_episode_count, 0) AS daemon_suspected_episode_count,
      COALESCE(ef.cooling_background_episode_count, 0) AS cooling_background_episode_count,
      COALESCE(ef.cooling_unassociated_episode_count, 0) AS cooling_unassociated_episode_count,
      COALESCE(ef.onset_unknown_episode_count, 0) AS onset_unknown_episode_count,
      COALESCE(wt.tied_cooling_device_count, 0) AS tied_cooling_device_count,
      ss.onset_count, ss.causal_onset_count, ss.confirmed_onset_count, ss.relaxed_onset_count,
      ss.trigger_class_rank,
      CASE
        WHEN ds.has_max_limit_data = 0 THEN ds.limit_evidence_classification
        WHEN COALESCE(ef.episode_count, 0) = 0 THEN 'NO_LIMIT_EPISODE'
        ELSE COALESCE(ss.trigger_class, 'LIMIT_ONSET_UNKNOWN')
      END AS freq_limit_classification,
      ss.onset_trigger_mix,
      ss.best_onset_verdict, ss.best_onset_ts, ss.best_paired_cdev_name,
      ds.has_max_limit_data, ds.limit_evidence_missing_reason,
      cov.cooling_transition_coverage,
      'window_scoped' AS classification_scope
    FROM system_windows w
    CROSS JOIN system_cpu_freq_limit_data_status ds
    CROSS JOIN thermal_cooling_transition_coverage cov
    JOIN _flv_scope_summary ss ON ss.scope = 'window' AND ss.window_id = w.window_id
    LEFT JOIN _flv_window_episode_facts ef ON ef.window_id = w.window_id
    LEFT JOIN _flv_window_tied_devices wt ON wt.window_id = w.window_id
  ) s
  JOIN system_cpu_freq_limit_trigger_classes c ON c.trigger_class = s.freq_limit_classification
),
system_cpu_freq_limit_trace_summary AS (
  SELECT s.*, c.is_confirmed, c.class_note
  FROM (
    SELECT te.episode_count,
      ss.onset_count, ss.causal_onset_count, ss.confirmed_onset_count, ss.relaxed_onset_count,
      ss.trigger_class_rank,
      CASE
        WHEN ds.has_max_limit_data = 0 THEN ds.limit_evidence_classification
        WHEN te.episode_count = 0 THEN 'NO_LIMIT_EPISODE'
        ELSE COALESCE(ss.trigger_class, 'LIMIT_ONSET_UNKNOWN')
      END AS freq_limit_classification,
      ss.onset_trigger_mix,
      ss.best_onset_verdict, ss.best_onset_ts, ss.best_paired_cdev_name,
      ds.has_max_limit_data, ds.limit_evidence_missing_reason,
      cov.cooling_transition_coverage,
      'trace_wide' AS classification_scope
    FROM system_cpu_freq_limit_data_status ds
    CROSS JOIN thermal_cooling_transition_coverage cov
    CROSS JOIN (SELECT COUNT(*) AS episode_count FROM system_cpu_freq_limit_trace_episodes) te
    JOIN _flv_scope_summary ss ON ss.scope = 'trace'
  ) s
  JOIN system_cpu_freq_limit_trigger_classes c ON c.trigger_class = s.freq_limit_classification
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Requires, injected before it: system_sched_spans.sql,
-- system_thread_state_spans.sql, system_cpu_frequency_spans.sql,
-- system_cpu_freq_limit_spans.sql, system_cpu_freq_limit_episodes.sql,
-- thermal_cooling_spans.sql, thermal_cdev_policy_association.sql,
-- thermal_signal_signatures.sql, system_cpu_freq_limit_episode_verdicts.sql.
-- Inputs defined by the consuming step:
--   system_windows(window_id, window_start_ts, window_end_ts)   one per frame
--   system_target_threads(window_id, upid, utid, role)
--   system_work_intervals(window_id, role, utid, work_start_ts, work_end_ts)
--     the interval each role's state is attributed to, one per (window, role);
--     a non-NULL utid restricts it to the thread that did that work (the top
--     slice's thread: a process can have several main-role threads, e.g.
--     Flutter *.ui), NULL counts every target thread of the role
-- Params (integer percentages, like the verdict layer's own thresholds):
--   ${freq_limit_binding_pct|90}       frequency / limit at or above which a
--                                      capped piece counts as binding
--   ${freq_limit_min_running_pct|50}   Running share of the work interval
--                                      below which the state is not judged
--   ${freq_limit_binding_min_pct|50}   binding share of Running time for
--                                      capped_binding
--   ${freq_limit_min_binding_ms|1}     minimum binding time for capped_binding
--   ${freq_limit_state_min_pct|50}     share of Running time that the other
--                                      states need (frequency coverage,
--                                      unknown, capped, limited policy)
--
-- Whether a frequency limit actually constrained the threads that did a
-- frame's work. The unit is time, not a window maximum: a piece is the
-- intersection of a target thread's Running interval, its attributed work
-- interval, the frequency span of the CPU it ran on, and the max-limit sample
-- of the policy that governs that CPU. A piece is capped when that sample is
-- capped (system_cpu_freq_limit_samples.is_capped, the one capping rule) and
-- binding when it is capped and the CPU ran at or above
-- freq_limit_binding_pct of the limit. Other threads running at the cap, or
-- the cap applying before or after the work, never make a frame binding.
--
-- Policy membership: a max-limit track names only the policy leader CPU. The
-- CPUs sharing the leader's cpu.cluster_id belong to the policy only when the
-- machine records more than one cluster and the leader's cluster holds exactly
-- one policy leader (`cpu_cluster_id`); otherwise only the leader itself
-- (`policy_leader_only`). A leader ordinal shared by several machines has no
-- identity and so no members. Identity follows system_cpu_frequency_spans:
-- machine_id + ucpu.
--
-- Trigger: this fragment never classifies what set a limit. Each piece keeps
-- the value onset of the sample in force for it
-- (system_cpu_freq_limit_samples.value_onset_counter_id), and the frame reads
-- that onset's verdict from system_cpu_freq_limit_onset_verdicts. The frame's
-- onset is the value covering the most binding time (ties: the earlier
-- value, never the one capped longer); the value onset precedes its pieces, so an onset after the work
-- interval never applies. `freq_limit_onset_confirmed` is 1 only when that
-- onset alone meets the capped_binding thresholds and its verdict is
-- confirmed; a frame that binds only by summing several values reads
-- `freq_limit_basis = 'mixed_limit_values_in_frame'`.
--
-- freq_limit_state, first match:
--   limit_track_unavailable        no valid max-limit sample in the trace
--   insufficient_running           Running below freq_limit_min_running_pct
--                                  of the work interval, or none
--   frequency_unavailable          frequency covers less than
--                                  freq_limit_state_min_pct of Running;
--                                  missing frequency is never "not binding"
--   capped_binding                 binding time meets both binding thresholds
--   limit_state_unknown            Running on a limited policy before its first
--                                  sample or under an invalid sample
--   capped_not_binding             capped, but the CPU ran below the limit
--   threads_not_on_limited_policy  Running mostly on CPUs no max limit governs
--   at_observed_max_limit          at the policy's observed maximum limit
-- The reference is the maximum limit observed in the trace, not the hardware
-- maximum. Every state is an observation, never a cause.
_flb_leaders AS (
  SELECT l.policy_cpu, c.id AS leader_ucpu, c.machine_id, c.cluster_id
  FROM (SELECT DISTINCT policy_cpu FROM system_cpu_freq_limit_raw WHERE kind = 'max') l
  JOIN cpu c ON c.cpu = l.policy_cpu
  WHERE (SELECT COUNT(*) FROM cpu c2 WHERE c2.cpu = l.policy_cpu) = 1
),
_flb_cluster_basis AS (
  SELECT l.policy_cpu,
    l.cluster_id IS NOT NULL
      AND (SELECT COUNT(DISTINCT c.cluster_id) FROM cpu c WHERE c.machine_id IS l.machine_id) > 1
      AND (SELECT COUNT(*) FROM _flb_leaders o
        WHERE o.machine_id IS l.machine_id AND o.cluster_id = l.cluster_id) = 1 AS by_cluster
  FROM _flb_leaders l
),
_flb_members AS MATERIALIZED (
  SELECT c.machine_id, c.id AS ucpu, l.policy_cpu,
    CASE WHEN b.by_cluster THEN 'cpu_cluster_id' ELSE 'policy_leader_only' END AS membership_basis
  FROM _flb_leaders l
  JOIN _flb_cluster_basis b ON b.policy_cpu = l.policy_cpu
  JOIN cpu c ON c.machine_id IS l.machine_id
    AND (CASE WHEN b.by_cluster THEN c.cluster_id = l.cluster_id ELSE c.id = l.leader_ucpu END)
),
_flb_work AS (
  SELECT window_id, role, SUM(work_end_ts - work_start_ts) AS work_ns
  FROM system_work_intervals
  WHERE work_end_ts > work_start_ts
  GROUP BY window_id, role
),
-- Nothing below is evaluated for a trace that cannot answer at all.
_flb_run AS MATERIALIZED (
  SELECT s.window_id, s.role, s.ucpu,
    MAX(s.clipped_start_ts, wi.work_start_ts) AS lo,
    MIN(s.clipped_end_ts, wi.work_end_ts) AS hi
  FROM system_thread_state_spans s
  JOIN system_work_intervals wi ON wi.window_id = s.window_id AND wi.role = s.role
    AND (wi.utid IS NULL OR wi.utid = s.utid)
  WHERE (SELECT has_max_limit_data FROM system_cpu_freq_limit_data_status) = 1
    AND s.state = 'Running'
    AND s.clipped_start_ts < wi.work_end_ts AND s.clipped_end_ts > wi.work_start_ts
),
_flb_rf AS MATERIALIZED (
  SELECT r.window_id, r.role, r.ucpu, f.freq_khz,
    MAX(r.lo, f.clipped_start_ts) AS lo, MIN(r.hi, f.clipped_end_ts) AS hi,
    m.policy_cpu, m.membership_basis
  FROM _flb_run r
  JOIN system_cpu_frequency_spans f ON f.window_id = r.window_id AND f.ucpu = r.ucpu
    AND f.clipped_start_ts < r.hi AND f.clipped_end_ts > r.lo
  LEFT JOIN _flb_members m ON m.ucpu = r.ucpu
),
_flb_piece AS MATERIALIZED (
  SELECT p.window_id, p.role, p.policy_cpu, p.membership_basis, p.freq_khz,
    s.limit_khz, s.reference_max_limit_khz, s.is_capped, s.value_onset_counter_id, s.value_onset_ts,
    MIN(p.hi, s.raw_end_ts) - MAX(p.lo, s.ts) AS dur_ns,
    CASE WHEN s.is_capped = 1
        AND p.freq_khz * 100 >= (${freq_limit_binding_pct|90}) * s.limit_khz
      THEN 1 ELSE 0 END AS is_binding
  FROM _flb_rf p
  JOIN system_cpu_freq_limit_samples s ON s.kind = 'max' AND s.limit_value_valid = 1
    AND s.policy_cpu = p.policy_cpu AND s.ts < p.hi AND s.raw_end_ts > p.lo
),
-- One row per limit value a frame's pieces ran under.
_flb_values AS (
  SELECT v.*,
    ROW_NUMBER() OVER (PARTITION BY v.window_id, v.role
      ORDER BY v.binding_ns DESC, v.value_onset_ts, v.value_onset_counter_id) AS value_rank
  FROM (
    SELECT window_id, role, policy_cpu, membership_basis, value_onset_counter_id, value_onset_ts,
      MAX(limit_khz) AS limit_khz, MAX(reference_max_limit_khz) AS reference_max_limit_khz,
      SUM(CASE WHEN is_capped = 1 THEN dur_ns ELSE 0 END) AS capped_ns,
      SUM(CASE WHEN is_binding = 1 THEN dur_ns ELSE 0 END) AS binding_ns,
      SUM(CASE WHEN is_capped = 1 THEN freq_khz * 1.0 * dur_ns ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_capped = 1 THEN limit_khz * 1.0 * dur_ns ELSE 0 END), 0) AS binding_ratio
    FROM _flb_piece
    GROUP BY window_id, role, policy_cpu, membership_basis, value_onset_counter_id, value_onset_ts
  ) v
  WHERE v.capped_ns > 0
),
_flb_policy_rank AS (
  SELECT window_id, role, policy_cpu, membership_basis,
    ROW_NUMBER() OVER (PARTITION BY window_id, role ORDER BY SUM(hi - lo) DESC, policy_cpu) AS policy_rank
  FROM _flb_rf
  WHERE policy_cpu IS NOT NULL
  GROUP BY window_id, role, policy_cpu, membership_basis
),
_flb_totals AS (
  SELECT w.window_id, w.role, w.work_ns,
    COALESCE(r.run_ns, 0) AS run_ns,
    COALESCE(f.freq_covered_ns, 0) AS freq_covered_ns,
    COALESCE(f.limited_policy_ns, 0) AS limited_policy_ns,
    COALESCE(p.limit_known_ns, 0) AS limit_known_ns,
    COALESCE(f.limited_policy_ns, 0) - COALESCE(p.limit_known_ns, 0) AS unknown_ns,
    COALESCE(p.capped_ns, 0) AS capped_ns,
    COALESCE(p.binding_ns, 0) AS binding_ns
  FROM _flb_work w
  LEFT JOIN (SELECT window_id, role, SUM(hi - lo) AS run_ns FROM _flb_run GROUP BY window_id, role) r
    ON r.window_id = w.window_id AND r.role = w.role
  LEFT JOIN (
    SELECT window_id, role, SUM(hi - lo) AS freq_covered_ns,
      SUM(CASE WHEN policy_cpu IS NOT NULL THEN hi - lo ELSE 0 END) AS limited_policy_ns
    FROM _flb_rf GROUP BY window_id, role
  ) f ON f.window_id = w.window_id AND f.role = w.role
  LEFT JOIN (
    SELECT window_id, role, SUM(dur_ns) AS limit_known_ns,
      SUM(CASE WHEN is_capped = 1 THEN dur_ns ELSE 0 END) AS capped_ns,
      SUM(CASE WHEN is_binding = 1 THEN dur_ns ELSE 0 END) AS binding_ns
    FROM _flb_piece GROUP BY window_id, role
  ) p ON p.window_id = w.window_id AND p.role = w.role
),
-- The trigger facts describe the capped value a frame ran under, so only a
-- capped frame carries them.
system_cpu_freq_limit_frame_binding AS MATERIALIZED (
  SELECT x.window_id, x.role, x.work_ns, x.run_ns, x.freq_covered_ns, x.limited_policy_ns,
    x.limit_known_ns, x.unknown_ns, x.capped_ns, x.binding_ns, x.running_share,
    x.policy_cpu, x.membership_basis, x.limit_khz, x.reference_max_limit_khz, x.depth_pct,
    x.binding_ratio, x.onset_binding_ns, x.freq_limit_state,
    CASE WHEN x.is_capped THEN x.onset_class END AS freq_limit_onset_class,
    CASE
      WHEN x.freq_limit_state = 'capped_binding' AND NOT x.onset_alone THEN 'mixed_limit_values_in_frame'
      WHEN x.is_capped THEN x.onset_class
    END AS freq_limit_basis,
    CASE WHEN x.freq_limit_state = 'capped_binding' AND x.onset_alone
      THEN COALESCE(x.onset_is_confirmed, 0) ELSE 0 END AS freq_limit_onset_confirmed,
    CASE WHEN x.is_capped THEN x.onset_ts END AS freq_limit_onset_ts,
    CASE WHEN x.is_capped THEN x.onset_cooling_basis END AS freq_limit_cooling_basis,
    CASE WHEN x.is_capped THEN x.onset_episode_id END AS trace_episode_id,
    'observation_not_causal' AS evidence_scope
  FROM (
    SELECT y.*,
      y.freq_limit_state IN ('capped_binding', 'capped_not_binding') AS is_capped,
      y.onset_binding_ns * 100 >= (${freq_limit_binding_min_pct|50}) * y.run_ns
        AND y.onset_binding_ns >= CAST((${freq_limit_min_binding_ms|1}) * 1000000 AS INTEGER) AS onset_alone
    FROM (
      SELECT t.window_id, t.role, t.work_ns, t.run_ns, t.freq_covered_ns, t.limited_policy_ns,
        t.limit_known_ns, t.unknown_ns, t.capped_ns, t.binding_ns,
        ROUND(1.0 * t.run_ns / NULLIF(t.work_ns, 0), 3) AS running_share,
        COALESCE(v.policy_cpu, pr.policy_cpu) AS policy_cpu,
        COALESCE(v.membership_basis, pr.membership_basis) AS membership_basis,
        v.limit_khz, v.reference_max_limit_khz,
        ROUND(100.0 * (v.reference_max_limit_khz - v.limit_khz) / NULLIF(v.reference_max_limit_khz, 0), 1) AS depth_pct,
        ROUND(v.binding_ratio, 3) AS binding_ratio,
        COALESCE(v.binding_ns, 0) AS onset_binding_ns,
        CASE
          WHEN ds.has_max_limit_data = 0 THEN 'limit_track_unavailable'
          WHEN t.run_ns = 0 OR t.run_ns * 100 < (${freq_limit_min_running_pct|50}) * t.work_ns
            THEN 'insufficient_running'
          WHEN t.freq_covered_ns * 100 < (${freq_limit_state_min_pct|50}) * t.run_ns THEN 'frequency_unavailable'
          WHEN t.binding_ns * 100 >= (${freq_limit_binding_min_pct|50}) * t.run_ns
            AND t.binding_ns >= CAST((${freq_limit_min_binding_ms|1}) * 1000000 AS INTEGER)
            THEN 'capped_binding'
          WHEN t.unknown_ns * 100 >= (${freq_limit_state_min_pct|50}) * t.run_ns THEN 'limit_state_unknown'
          WHEN t.capped_ns * 100 >= (${freq_limit_state_min_pct|50}) * t.run_ns THEN 'capped_not_binding'
          WHEN t.limited_policy_ns * 100 < (${freq_limit_state_min_pct|50}) * t.run_ns
            THEN 'threads_not_on_limited_policy'
          ELSE 'at_observed_max_limit'
        END AS freq_limit_state,
        ov.trigger_class AS onset_class, ov.is_confirmed AS onset_is_confirmed,
        ov.cooling_basis AS onset_cooling_basis, v.value_onset_ts AS onset_ts, ov.trace_episode_id AS onset_episode_id
      FROM _flb_totals t
      CROSS JOIN system_cpu_freq_limit_data_status ds
      LEFT JOIN _flb_values v ON v.window_id = t.window_id AND v.role = t.role AND v.value_rank = 1
      LEFT JOIN _flb_policy_rank pr ON pr.window_id = t.window_id AND pr.role = t.role AND pr.policy_rank = 1
      LEFT JOIN system_cpu_freq_limit_onset_verdicts ov ON ov.counter_id = v.value_onset_counter_id
    ) y
  ) x
)
,
-- ========== 1. VSync 配置 ==========
timing_config AS (
  SELECT
    vsync_period_ns,
    vsync_source,
    ROUND(vsync_period_ns / 1e6, 2) as frame_budget_ms,
    ROUND(vsync_period_ns / 1e6 * 0.50, 2) as slice_critical_ms,
    ROUND(MAX(vsync_period_ns / 1e6 * 0.35, 2.0), 2) as freq_ramp_critical_ms,
    ROUND(MAX(vsync_period_ns / 1e6 * 0.18, 1.5), 2) as binder_overlap_critical_ms
  FROM vsync_config
),
-- ========== 1b. 设备峰值频率（全 trace 大核最高观测频率，仅作观测列）==========
-- 不加 start_ts/end_ts 过滤；用 MAX — P95 会被大量空闲低频样本主导。
-- 它不是硬件上限，也不是限频证据：频率低于峰值既可能是被限频，也可能只是负载
-- 下降。限频根因只读 system_cpu_freq_limit_frame_binding（policy 上限轨道 ×
-- 线程实际运行时间），不再由这个比例判定。
device_peak_freq AS (
  SELECT COALESCE(ROUND(MAX(c.value) / 1000, 0), 0) as device_peak_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id AND cct.name = 'cpufreq'
  LEFT JOIN _cpu_topology ct ON cct.cpu = ct.cpu_id
  WHERE ct.core_type IN ('prime', 'big', 'medium')
),
-- ========== 2. Per-layer 帧序列 + 双信号混合掉帧检测（与 get_app_jank_frames 一致）==========
layer_frames AS (
  SELECT
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key,
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.surface_frame_token as surface_frame_token,
    CASE WHEN a.name GLOB '[0-9]*' THEN CAST(a.name AS INTEGER) ELSE NULL END as timeline_frame_id,
    a.ts as frame_start,
    a.ts + a.dur as frame_end,
    a.dur as frame_dur,
    a.jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.upid,
    a.layer_name,
    -- JANK_RESPONSIBILITY_CASE_BEGIN
    CASE
      WHEN a.jank_type GLOB '*Self Jank*' OR android_is_app_jank_type(a.jank_type) THEN 'APP'
      WHEN a.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN a.jank_type GLOB '*Buffer Stuffing*' THEN 'BUFFER_STUFFING'
      WHEN android_is_sf_jank_type(a.jank_type) THEN 'SF'
      WHEN a.jank_type = 'None' OR a.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END
    -- JANK_RESPONSIBILITY_CASE_END
    as jank_responsibility,
    COALESCE(a.display_frame_token, a.surface_frame_token) - LAG(COALESCE(a.display_frame_token, a.surface_frame_token))
      OVER (PARTITION BY a.upid, a.layer_name ORDER BY COALESCE(a.display_frame_token, a.surface_frame_token)) AS token_gap,
    a.ts - LAG(a.ts + a.dur)
      OVER (PARTITION BY a.upid, a.layer_name ORDER BY a.ts) AS time_gap_ns,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END AS present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.upid, a.layer_name ORDER BY a.ts) AS prev_present_ts
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
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT *,
    CASE WHEN time_gap_ns IS NULL OR time_gap_ns > (SELECT vsync_period_ns * 6 FROM timing_config) THEN 1 ELSE 0 END as new_session
  FROM layer_frames
),
sessions_map AS (
  SELECT *,
    SUM(new_session) OVER (PARTITION BY layer_name ORDER BY frame_start) as session_id
  FROM session_markers
),
-- 掉帧检测：双信号混合策略（与 jank_frames 保持一致）
all_jank_frames AS (
  SELECT
    sm.frame_key,
    sm.display_frame_token,
    sm.surface_frame_token,
    sm.timeline_frame_id,
    sm.frame_start,
    sm.frame_end,
    sm.frame_dur,
    sm.jank_type,
    sm.upid,
    sm.session_id,
    p.pid,
    p.name as process_name,
    sm.layer_name,
    ROUND(sm.frame_dur / 1e6, 2) as dur_ms,
    sm.jank_responsibility,
    CASE
      WHEN sm.prev_present_ts IS NOT NULL AND sm.present_ts - sm.prev_present_ts > tc.vsync_period_ns * 1.5
        THEN MAX(CAST(ROUND((sm.present_ts - sm.prev_present_ts) * 1.0 / tc.vsync_period_ns - 1, 0) AS INTEGER), 0)
      ELSE 1  -- at least 1 vsync missed if present_type is Late/Dropped
    END as vsync_missed,
    CASE
      WHEN sm.prev_present_ts IS NOT NULL
        THEN ROUND((sm.present_ts - sm.prev_present_ts) / 1e6, 2)
      ELSE NULL
    END as present_interval_ms
  FROM sessions_map sm
  CROSS JOIN timing_config tc
  JOIN effective_target_processes p ON sm.upid = p.upid
  WHERE (
    -- 非 BS：present_type 为权威信号
    (sm.present_type IN ('Late Present', 'Dropped Frame')
      AND (sm.jank_responsibility != 'BUFFER_STUFFING' OR android_is_missed_frame_type(sm.jank_type)))
    OR
    -- BS + 异常间隔：真实掉帧被 BS 掩盖
    (sm.jank_responsibility = 'BUFFER_STUFFING'
     AND sm.prev_present_ts IS NOT NULL
     AND (sm.present_ts - sm.prev_present_ts) > tc.vsync_period_ns * 1.5
     AND (sm.present_ts - sm.prev_present_ts) <= tc.vsync_period_ns * 6)
  )
  -- 排除会话间断帧
  AND (sm.time_gap_ns IS NULL OR sm.time_gap_ns <= tc.vsync_period_ns * 6)
),
-- BATCH_DISPLAY_DEDUP_CTE_BEGIN
deduped_jank_frames AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY frame_key
      ORDER BY
        CASE jank_responsibility
          WHEN 'APP' THEN 1
          WHEN 'SF' THEN 2
          WHEN 'BUFFER_STUFFING' THEN 3
          WHEN 'HIDDEN' THEN 4
          ELSE 5
        END,
        vsync_missed DESC,
        frame_dur DESC,
        layer_name ASC
    ) as display_frame_rank
  FROM all_jank_frames
),
-- BATCH_DISPLAY_DEDUP_CTE_END
-- 按严重度排序（与 get_app_jank_frames 完全一致的 rank_in_session 逻辑）
ranked_jank_frames AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY vsync_missed DESC, frame_dur DESC) as rank_in_session
  FROM deduped_jank_frames
  WHERE display_frame_rank = 1
),
-- BATCH_ROOT_CAUSE_SCOPE_CTES_BEGIN
-- root_cause_sample_config comes from fragments/root_cause_sample_cap.sql
root_cause_population AS (
  SELECT
    COUNT(*) as root_cause_eligible_frame_count,
    COALESCE(SUM(CASE
      WHEN rank_in_session <= (SELECT root_cause_sample_limit_per_session FROM root_cause_sample_config)
      THEN 1 ELSE 0 END
    ), 0) as root_cause_analyzed_frame_count,
    CASE
      WHEN COUNT(*) = 0 THEN 1.0
      ELSE ROUND(1.0 * COALESCE(SUM(CASE
        WHEN rank_in_session <= (SELECT root_cause_sample_limit_per_session FROM root_cause_sample_config)
        THEN 1 ELSE 0 END
      ), 0) / COUNT(*), 4)
    END as root_cause_coverage_ratio,
    (SELECT root_cause_sample_limit_per_session FROM root_cause_sample_config) as root_cause_sample_limit_per_session,
    CASE
      WHEN COALESCE(SUM(CASE
        WHEN rank_in_session <= (SELECT root_cause_sample_limit_per_session FROM root_cause_sample_config)
        THEN 1 ELSE 0 END
      ), 0) < COUNT(*) THEN 'capped_frame_sample'
      ELSE 'full_frame_set'
    END as root_cause_analysis_scope
  FROM ranked_jank_frames
),
-- BATCH_ROOT_CAUSE_SCOPE_CTES_END
-- 截断后重新编号（与 get_app_jank_frames 的 frame_index 完全对齐）
jank_frame_list AS (
  SELECT
    frame_key, display_frame_token, surface_frame_token, timeline_frame_id, frame_start, frame_end, frame_dur, jank_type, upid, session_id,
    pid, process_name, layer_name, dur_ms, jank_responsibility, vsync_missed, present_interval_ms,
    ROW_NUMBER() OVER (ORDER BY session_id, frame_start) as frame_index
  FROM ranked_jank_frames
  WHERE rank_in_session <= (
    SELECT root_cause_sample_limit_per_session
    FROM root_cause_sample_config
  )
),
-- ========== 3. Explicit role-based thread identification ==========
-- Main thread:   t.tid = p.pid (standard Android) OR t.name GLOB '*.ui' (Flutter)
-- RenderThread:  t.name = 'RenderThread' (standard Android) OR t.name GLOB '*.raster' (Flutter)
-- Aligned with the jank_frame_detail.skill.yaml proven approach.
per_frame_thread_roles AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    t.utid,
    t.tid,
    t.name as thread_name,
    CASE
      WHEN t.tid = p.pid THEN 'main'
      WHEN t.name GLOB '[0-9]*.ui' THEN 'main'
      WHEN t.name = 'RenderThread' THEN 'render'
      WHEN t.name GLOB '[0-9]*.raster' THEN 'render'
    END as role
  FROM jank_frame_list fl
  JOIN effective_target_processes p ON fl.upid = p.upid
  JOIN thread t ON t.upid = fl.upid
  WHERE t.tid = p.pid
    OR t.name = 'RenderThread'
    OR t.name GLOB '[0-9]*.ui'
    OR t.name GLOB '[0-9]*.raster'
),
-- ========== 4. Per-frame: 最耗时 producer 线程 slice ==========
-- Choreographer#doFrame - resynced... is a child marker showing
-- frame-timeline resynchronization; exclude it from workload ranking.
frame_slices AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    s.name as slice_name,
    s.ts as slice_ts,
    s.dur as slice_dur_ns,
    ROUND(s.dur / 1e6, 2) as slice_dur_ms,
    ROUND((s.ts - fl.frame_start) / 1e6, 2) as slice_offset_ms,
    ptr.utid as slice_utid,
    ROW_NUMBER() OVER (PARTITION BY fl.frame_key ORDER BY s.dur DESC) as rn
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts >= fl.frame_start - 5000000
    AND s.ts < fl.frame_end
    AND s.dur >= 1000000
    AND s.name NOT GLOB '*resynced*'
),
top_slices AS (
  SELECT * FROM frame_slices WHERE rn = 1
),
system_windows AS (
  SELECT frame_key AS window_id,frame_start AS window_start_ts,frame_end AS window_end_ts FROM jank_frame_list
),
system_target_threads AS (
  SELECT ptr.frame_key AS window_id,fl.upid,ptr.utid,ptr.role
  FROM per_frame_thread_roles ptr JOIN jank_frame_list fl ON fl.frame_key=ptr.frame_key
),
-- The interval the frequency-limit state of each role is attributed to: the
-- top slice clipped to the frame, on the thread that ran it (the same clip as
-- top_slice_states, so P4.5/P4.6 judge the work that top_slice_ms measures;
-- other main-role threads such as Flutter *.ui never count), and the whole
-- frame for RenderThread, whose state is diagnostic only.
system_work_intervals AS (
  SELECT ts_top.frame_key AS window_id,'main' AS role,ts_top.slice_utid AS utid,
    MAX(ts_top.slice_ts,fl.frame_start) AS work_start_ts,
    MIN(ts_top.slice_ts+ts_top.slice_dur_ns,fl.frame_end) AS work_end_ts
  FROM top_slices ts_top JOIN jank_frame_list fl ON fl.frame_key=ts_top.frame_key
  UNION ALL
  SELECT frame_key,'render',NULL,frame_start,frame_end FROM jank_frame_list
),
frame_system_states AS (
  SELECT s.*,COALESCE(ct.core_type,'unknown') AS core_type
  FROM system_thread_state_spans s LEFT JOIN system_cpu_topology ct ON ct.ucpu=s.ucpu
),
-- ========== 5. Per-frame top slice: 核心类型 + 调度分析 ==========
top_slice_states AS (
  SELECT s.window_id AS frame_key,s.window_start_ts AS frame_start,s.state,s.core_type,
    MIN(s.clipped_end_ts,ts_top.slice_ts+ts_top.slice_dur_ns)-MAX(s.clipped_start_ts,ts_top.slice_ts) AS overlap_ns
  FROM frame_system_states s JOIN top_slices ts_top ON ts_top.frame_key=s.window_id
  WHERE s.role='main' AND s.clipped_start_ts<ts_top.slice_ts+ts_top.slice_dur_ns AND s.clipped_end_ts>ts_top.slice_ts
),
per_frame_cpu_mix AS (
  SELECT
    frame_key,
    frame_start,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type = 'little' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as little_run_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as big_run_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('R', 'R+') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as runnable_pct
  FROM top_slice_states
  GROUP BY frame_key, frame_start
),
-- ========== 6. Per-frame: 主线程四象限 ==========
frame_thread_states AS (
  SELECT window_id AS frame_key,window_start_ts AS frame_start,state,core_type,dur_ns AS overlap_ns
  FROM frame_system_states WHERE role='main'
),
per_frame_quadrants AS (
  SELECT
    frame_key,
    frame_start,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q1_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type = 'little' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q2_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('R', 'R+') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q3_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('D', 'DK') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q4a_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('S', 'I') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as q4b_pct
  FROM frame_thread_states
  GROUP BY frame_key, frame_start
),
-- ========== 6b. Per-frame: 渲染线程四象限 ==========
render_thread_states AS (
  SELECT window_id AS frame_key,window_start_ts AS frame_start,state,core_type,dur_ns AS overlap_ns
  FROM frame_system_states WHERE role='render'
),
render_thread_quadrants AS (
  SELECT
    frame_key,
    frame_start,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q1_pct,
    ROUND(100.0 * SUM(CASE WHEN state = 'Running' AND core_type = 'little' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q2_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('R', 'R+') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q3_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('D', 'DK') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q4a_pct,
    ROUND(100.0 * SUM(CASE WHEN state IN ('S', 'I') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF(SUM(CASE WHEN overlap_ns > 0 THEN overlap_ns ELSE 0 END), 0), 1) as render_q4b_pct
  FROM render_thread_states
  GROUP BY frame_key, frame_start
),
-- ========== 7. Per-frame: 大核频率 ==========
-- BATCH_FRAME_IDENTITY_FREQ_CTE_BEGIN
per_frame_freq AS (
  SELECT f.window_id AS frame_key,f.window_start_ts AS frame_start,
    ROUND(SUM(f.freq_khz*1.0*f.dur_ns)/NULLIF(SUM(f.dur_ns),0)/1000,0) AS big_avg_freq_mhz,
    ROUND(MAX(f.freq_khz)/1000,0) AS big_max_freq_mhz,
    SUM(f.dur_ns) AS frequency_covered_ns
  FROM system_cpu_frequency_spans f JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  WHERE ct.core_type IN ('prime','big','medium') GROUP BY f.window_id,f.window_start_ts
),
-- BATCH_FRAME_IDENTITY_FREQ_CTE_END
-- ========== 8. Per-frame: 频率爬升延迟 ==========
-- 只对整帧每个大核都有频率观测的帧计时（fragments/system_cpu_big_freq_coverage.sql，
-- 与 jank_frame_detail 同一证据判定，高频阈值各自不同）；其余帧 ramp 为 NULL，不是"瞬间升到高频"的 0
frame_peak_freq AS (
  SELECT f.window_id AS frame_key,MAX(f.freq_khz) AS peak_khz
  FROM system_cpu_frequency_spans f JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  WHERE ct.core_type IN ('prime','big','medium') GROUP BY f.window_id
),
per_frame_ramp AS (
  SELECT f.window_id AS frame_key,f.window_start_ts AS frame_start,
    ROUND((MIN(CASE WHEN f.freq_khz>=p.peak_khz*0.7 THEN f.clipped_start_ts END)-f.window_start_ts)/1e6,2) AS ramp_to_high_ms
  FROM system_cpu_frequency_spans f JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  JOIN frame_peak_freq p ON p.frame_key=f.window_id
  JOIN system_cpu_big_freq_coverage cov ON cov.window_id=f.window_id AND cov.freq_ramp_evidence='observed'
  WHERE ct.core_type IN ('prime','big','medium') GROUP BY f.window_id,f.window_start_ts
),
-- ========== 9. Per-frame: Binder 同步与 top slice 重叠 ==========
per_frame_binder AS (
  SELECT
    ts_top.frame_key,
    ts_top.frame_start,
    ROUND(COALESCE(SUM(
      CASE
        WHEN bt.client_ts < ts_top.slice_ts + ts_top.slice_dur_ns
          AND bt.client_ts + bt.client_dur > ts_top.slice_ts
        THEN (
          MIN(bt.client_ts + bt.client_dur, ts_top.slice_ts + ts_top.slice_dur_ns) -
          MAX(bt.client_ts, ts_top.slice_ts)
        )
        ELSE 0
      END
    ), 0) / 1e6, 2) as binder_overlap_ms
  FROM top_slices ts_top
  JOIN per_frame_thread_roles ptr ON ptr.frame_key = ts_top.frame_key AND ptr.role = 'main'
  LEFT JOIN android_binder_txns bt ON bt.client_utid = ptr.utid
    AND bt.is_sync = 1
    AND bt.client_ts < ts_top.slice_ts + ts_top.slice_dur_ns
    AND bt.client_ts + bt.client_dur > ts_top.slice_ts
  GROUP BY ts_top.frame_key, ts_top.frame_start
),
-- ========== 9.5. Per-frame: GPU fence 等待检测 ==========
gpu_fence_per_frame AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    MAX(CASE WHEN s.name GLOB '*Fence*' OR s.name GLOB '*fence*' OR s.name GLOB '*eglSwapBuffers*' OR s.name GLOB '*dequeueBuffer*'
         THEN s.dur ELSE 0 END) as max_fence_dur_ns,
    SUM(CASE WHEN s.name GLOB '*Fence*' OR s.name GLOB '*fence*' OR s.name GLOB '*eglSwapBuffers*' OR s.name GLOB '*dequeueBuffer*'
         THEN s.dur ELSE 0 END) as total_fence_dur_ns
  FROM jank_frame_list fl
  JOIN slice s ON s.ts >= fl.frame_start AND s.ts < fl.frame_end
  JOIN thread_track tk ON s.track_id = tk.id
  JOIN thread t ON tk.utid = t.utid
  WHERE t.upid = fl.upid  -- same process only (no thread name filter needed)
  GROUP BY fl.frame_key, fl.frame_start
),
-- ========== 9.6. Per-frame: Shader compilation 检测 ==========
shader_per_frame AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    COUNT(*) as shader_count,
    SUM(s.dur) as total_shader_dur_ns
  FROM jank_frame_list fl
  JOIN slice s ON s.ts >= fl.frame_start AND s.ts < fl.frame_end
  JOIN thread_track tk ON s.track_id = tk.id
  JOIN thread t ON tk.utid = t.utid
  WHERE t.upid = fl.upid  -- same process only (no thread name filter needed)
    AND (s.name GLOB '*shader*' OR s.name GLOB '*Shader*' OR s.name GLOB '*compile*' OR s.name GLOB '*Compile*')
  GROUP BY fl.frame_key, fl.frame_start
),
-- ========== 9.7. Per-frame: GC 事件与帧窗口重叠 ==========
per_frame_gc AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    ROUND(COALESCE(SUM(
      MIN(gc.gc_ts + gc.gc_dur, fl.frame_end) - MAX(gc.gc_ts, fl.frame_start)
    ), 0) / 1e6, 2) as gc_overlap_ms,
    COUNT(gc.gc_ts) as gc_count
  FROM jank_frame_list fl
  LEFT JOIN (
    SELECT gc.upid, gc.gc_ts, gc.gc_dur
    FROM android_garbage_collection_events gc
    JOIN thread t ON gc.utid = t.utid
    JOIN effective_target_processes p ON t.upid = p.upid
    WHERE (
      ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
      OR p.name = '${package}'
      OR p.name GLOB '${package}:*'
    )
  ) gc ON gc.upid = fl.upid AND gc.gc_ts < fl.frame_end AND gc.gc_ts + gc.gc_dur > fl.frame_start
  GROUP BY fl.frame_key, fl.frame_start
),
-- ========== 10. 批量详情 JSON 列（覆盖全部掉帧，避免 N+1 查询） ==========
-- 10a. 全簇 CPU 频率 (prime/big/little)
per_frame_cpu_clusters AS (
  SELECT frame_key,frame_start,json_group_array(json_object(
    'core_type',core_type,'avg_mhz',avg_mhz,'max_mhz',max_mhz,'min_mhz',min_mhz,
    'frequency_covered_ns',frequency_covered_ns,'observed_cpu_count',observed_cpu_count
  )) AS cpu_freq_clusters_json
  FROM (
    SELECT f.window_id AS frame_key,f.window_start_ts AS frame_start,COALESCE(ct.core_type,'unknown') AS core_type,
      CAST(ROUND(SUM(f.freq_khz*1.0*f.dur_ns)/NULLIF(SUM(f.dur_ns),0)/1000,0) AS INTEGER) AS avg_mhz,
      CAST(ROUND(MAX(f.freq_khz)/1000,0) AS INTEGER) AS max_mhz,
      CAST(ROUND(MIN(f.freq_khz)/1000,0) AS INTEGER) AS min_mhz,
      SUM(f.dur_ns) AS frequency_covered_ns,COUNT(DISTINCT f.ucpu) AS observed_cpu_count
    FROM system_cpu_frequency_spans f LEFT JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
    GROUP BY f.window_id,f.window_start_ts,ct.core_type
  ) GROUP BY frame_key,frame_start
),
-- 10b. 各 CPU 频率变化时间线（频率单位 GHz）
frame_frequency_events AS (
  SELECT f.*,COALESCE(ct.core_type,'unknown') AS core_type,
    COALESCE(ct.topology_source,'cpu_identity_unavailable') AS topology_source,
    LAG(f.freq_khz) OVER (PARTITION BY f.window_id,f.ucpu ORDER BY f.raw_start_ts,f.counter_id) AS prev_freq_khz
  FROM system_cpu_frequency_spans f LEFT JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
),
ranked_frequency_changes AS (
  SELECT *,ROW_NUMBER() OVER (PARTITION BY window_id ORDER BY raw_start_ts,ucpu,counter_id) AS rn,
    COUNT(*) OVER (PARTITION BY window_id) AS total_change_count
  FROM frame_frequency_events
  WHERE raw_start_ts>=window_start_ts AND raw_start_ts<window_end_ts
    AND (prev_freq_khz IS NULL OR freq_khz!=prev_freq_khz)
),
per_frame_freq_changes AS (
  SELECT window_id AS frame_key,window_start_ts AS frame_start,
    json_group_array(json_object(
      'relative_ms',ROUND((raw_start_ts-window_start_ts)/1e6,2),
      'source_ts',raw_start_ts,'cpu',cpu,'ucpu',ucpu,'counter_id',counter_id,'track_id',track_id,
      'core_type',core_type,'topology_source',topology_source,'freq_ghz',ROUND(freq_khz/1e6,2),
      'prev_freq_ghz',ROUND(prev_freq_khz/1e6,2),
      'change',CASE WHEN prev_freq_khz IS NULL THEN 'unknown'
        WHEN freq_khz>prev_freq_khz THEN 'up' WHEN freq_khz<prev_freq_khz THEN 'down' ELSE 'stable' END,
      'total_change_count',total_change_count,'evidence_scope','recorded_counter_events_not_residence_average'
    )) AS freq_timeline_json
  FROM ranked_frequency_changes WHERE rn<=30 GROUP BY window_id,window_start_ts
),
-- 10c. 主线程 Top 8 耗时 Slice
-- Keep resync markers out of generic main-thread workload slices.
per_frame_main_top_slices AS (
  SELECT frame_key, frame_start,
    json_group_array(json_object(
      'name', slice_name,
      'total_ms', dur_ms,
      'count', cnt,
      'max_ms', max_ms,
      'ts', ts_str
    )) as main_slices_json
  FROM (
    SELECT
      fl.frame_key,
      fl.frame_start,
      s.name as slice_name,
      ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
      COUNT(*) as cnt,
      ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
      printf('%d', MIN(s.ts)) as ts_str,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_key ORDER BY SUM(s.dur) DESC) as rn
    FROM jank_frame_list fl
    JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'main'
    JOIN thread_track tt ON tt.utid = ptr.utid
    JOIN slice s ON s.track_id = tt.id
      AND s.ts >= fl.frame_start - 5000000
      AND s.ts < fl.frame_end
      AND s.dur >= 500000
      AND s.name NOT GLOB '*resynced*'
    GROUP BY fl.frame_key, fl.frame_start, s.name
    HAVING dur_ms > 0.5
  )
  WHERE rn <= 8
  GROUP BY frame_key, frame_start
),
-- 10d. RenderThread Top 8 耗时 Slice
per_frame_render_top_slices AS (
  SELECT frame_key, frame_start,
    json_group_array(json_object(
      'name', slice_name,
      'total_ms', dur_ms,
      'count', cnt,
      'max_ms', max_ms,
      'ts', ts_str
    )) as render_slices_json
  FROM (
    SELECT
      fl.frame_key,
      fl.frame_start,
      s.name as slice_name,
      ROUND(SUM(s.dur) / 1e6, 2) as dur_ms,
      COUNT(*) as cnt,
      ROUND(MAX(s.dur) / 1e6, 2) as max_ms,
      printf('%d', MIN(s.ts)) as ts_str,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_key ORDER BY SUM(s.dur) DESC) as rn
    FROM jank_frame_list fl
    JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'render'
    JOIN thread_track tt ON tt.utid = ptr.utid
    JOIN slice s ON s.track_id = tt.id
      AND s.ts >= fl.frame_start - 5000000
      AND s.ts < fl.frame_end
      AND s.dur >= 500000
    GROUP BY fl.frame_key, fl.frame_start, s.name
    HAVING dur_ms > 0.5
  )
  WHERE rn <= 8
  GROUP BY frame_key, frame_start
),
-- 10e. Binder 调用详情（按 server_process 聚合，Top 5）
per_frame_binder_detail AS (
  SELECT frame_key, frame_start,
    json_group_array(json_object(
      'server', server_process,
      'count', cnt,
      'dur_ms', dur_ms,
      'max_ms', max_ms
    )) as binder_calls_json
  FROM (
    SELECT
      fl.frame_key,
      fl.frame_start,
      bt.server_process,
      COUNT(*) as cnt,
      ROUND(SUM(bt.client_dur) / 1e6, 2) as dur_ms,
      ROUND(MAX(bt.client_dur) / 1e6, 2) as max_ms,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_key ORDER BY SUM(bt.client_dur) DESC) as rn
    FROM jank_frame_list fl
    JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'main'
    LEFT JOIN android_binder_txns bt ON bt.client_utid = ptr.utid
      AND bt.client_ts >= fl.frame_start
      AND bt.client_ts < fl.frame_end
    WHERE bt.server_process IS NOT NULL
    GROUP BY fl.frame_key, fl.frame_start, bt.server_process
    HAVING dur_ms > 0.1
  )
  WHERE rn <= 5
  GROUP BY frame_key, frame_start
),
-- 10f. GC 事件详情（按类型聚合）
per_frame_gc_detail AS (
  SELECT frame_key, frame_start,
    json_group_array(json_object(
      'gc_type', gc_type,
      'count', cnt,
      'total_ms', total_dur_ms,
      'overlap_ms', overlap_ms
    )) as gc_events_json
  FROM (
    SELECT
      fl.frame_key,
      fl.frame_start,
      COALESCE(gc.gc_type, 'unknown') as gc_type,
      COUNT(*) as cnt,
      ROUND(SUM(gc.gc_dur) / 1e6, 2) as total_dur_ms,
      ROUND(SUM(
        MAX(MIN(gc.gc_ts + gc.gc_dur, fl.frame_end) - MAX(gc.gc_ts, fl.frame_start), 0)
      ) / 1e6, 2) as overlap_ms
    FROM jank_frame_list fl
    LEFT JOIN (
      SELECT gc.upid, gc.gc_ts, gc.gc_dur, gc.gc_type, t.tid
      FROM android_garbage_collection_events gc
      JOIN thread t ON gc.utid = t.utid
      JOIN effective_target_processes p ON t.upid = p.upid
      WHERE (
        ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
        OR p.name = '${package}'
        OR p.name GLOB '${package}:*'
      )
    ) gc ON gc.upid = fl.upid AND gc.gc_ts < fl.frame_end AND gc.gc_ts + gc.gc_dur > fl.frame_start
    WHERE gc.gc_ts IS NOT NULL
    GROUP BY fl.frame_key, fl.frame_start, COALESCE(gc.gc_type, 'unknown')
    HAVING overlap_ms > 0
  )
  GROUP BY frame_key, frame_start
),
-- 10g. 锁竞争：全量 overlap 参与 numeric 归因，Top 5 仅限制展示 JSON。
per_frame_lock_overlap AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    amc.short_blocking_method as blocking_method,
    amc.blocking_thread_name,
    amc.dur as raw_dur_ns,
    ROUND(MAX(
      MIN(amc.ts + amc.dur, fl.frame_end) - MAX(amc.ts, fl.frame_start),
      0
    ) / 1e6, 2) as wait_ms,
    CASE WHEN amc.is_blocked_thread_main THEN 1 ELSE 0 END as main_blocked
  FROM jank_frame_list fl
  JOIN android_monitor_contention amc
    ON amc.upid = fl.upid AND amc.ts < fl.frame_end
    AND amc.ts + amc.dur > fl.frame_start
    AND (
      ${__process_scope.upid} IS NOT NULL OR '${package}' = ''
      OR amc.process_name = '${package}'
      OR amc.process_name GLOB '${package}:*'
    )
    AND amc.dur >= 200000
),
per_frame_lock_detail AS (
  SELECT
    overlap.frame_key,
    overlap.frame_start,
    ROUND(SUM(
      CASE WHEN overlap.main_blocked = 1 THEN overlap.wait_ms ELSE 0 END
    ), 2) as lock_contention_ms,
    COALESCE((
      SELECT json_group_array(json_object(
        'method', display.blocking_method,
        'blocker', display.blocking_thread_name,
        'wait_ms', display.wait_ms,
        'main_blocked', display.main_blocked
      ))
      FROM (
        SELECT blocking_method, blocking_thread_name, wait_ms, main_blocked
        FROM per_frame_lock_overlap ranked
        WHERE ranked.frame_key = overlap.frame_key
        ORDER BY ranked.raw_dur_ns DESC
        LIMIT 5
      ) display
    ), '[]') as lock_contention_json
  FROM per_frame_lock_overlap overlap
  GROUP BY overlap.frame_key, overlap.frame_start
),
-- 10g.5. 主线程等待 RenderThread 的直接同步边界。
-- Q4b(S/I) 只是可中断睡眠观察值；同步 slice 先裁剪到帧窗口并做区间并集，
-- 避免 syncAndDrawFrame/postAndWait 等父子 slice 被重复计时。
-- BATCH_RENDER_SYNC_CTES_BEGIN
per_frame_render_sync_intervals AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    MAX(s.ts, fl.frame_start) as sync_start,
    MIN(s.ts + s.dur, fl.frame_end) as sync_end
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < fl.frame_end
    AND s.ts + s.dur > fl.frame_start
    AND (
      s.name GLOB '*postAndWait*'
      OR s.name GLOB '*syncAndDrawFrame*'
      OR s.name GLOB '*syncFrameState*'
    )
),
per_frame_render_sync_ordered AS (
  SELECT
    *,
    MAX(sync_end) OVER (
      PARTITION BY frame_key
      ORDER BY sync_start, sync_end
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) as previous_max_end
  FROM per_frame_render_sync_intervals
  WHERE sync_end > sync_start
),
per_frame_render_sync_labeled AS (
  SELECT
    *,
    SUM(
      CASE
        WHEN previous_max_end IS NULL OR sync_start > previous_max_end THEN 1
        ELSE 0
      END
    ) OVER (
      PARTITION BY frame_key
      ORDER BY sync_start, sync_end
      ROWS UNBOUNDED PRECEDING
    ) as interval_group
  FROM per_frame_render_sync_ordered
),
per_frame_render_sync_union AS (
  SELECT
    frame_key,
    frame_start,
    interval_group,
    MIN(sync_start) as sync_start,
    MAX(sync_end) as sync_end
  FROM per_frame_render_sync_labeled
  GROUP BY frame_key, frame_start, interval_group
),
per_frame_render_sync_wait AS (
  SELECT
    frame_key,
    frame_start,
    ROUND(SUM(sync_end - sync_start) / 1e6, 2) as render_sync_wait_ms
  FROM per_frame_render_sync_union
  GROUP BY frame_key, frame_start
),
-- BATCH_RENDER_SYNC_CTES_END
per_frame_render_sync_work AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    ROUND(COALESCE(MAX(
      MAX(MIN(s.ts + s.dur, fl.frame_end) - MAX(s.ts, fl.frame_start), 0)
    ), 0) / 1e6, 2) as render_sync_rt_work_ms
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'render'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < fl.frame_end
    AND s.ts + s.dur > fl.frame_start
    AND (
      s.name GLOB '*syncFrameState*'
      OR s.name GLOB '*DrawFrame*'
    )
  GROUP BY fl.frame_key, fl.frame_start
),
-- 10h. 主线程文件 IO 检测（SharedPreferences/sqlite/fsync 等 IO slice 与帧窗口重叠）
-- BATCH_FRAME_IDENTITY_FILE_IO_CTE_BEGIN
per_frame_file_io AS (
  SELECT fl.frame_key, fl.frame_start,
    ROUND(SUM(
      MAX(MIN(s.ts + s.dur, fl.frame_end) - MAX(s.ts, fl.frame_start), 0)
    ) / 1e6, 2) as file_io_overlap_ms
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < fl.frame_end AND s.ts + s.dur > fl.frame_start
    AND s.dur > 500000
  WHERE s.name GLOB '*SharedPreferences*'
    OR s.name GLOB '*getSharedPreferences*'
    OR s.name GLOB '*commit*SharedPref*'
    OR s.name GLOB '*QueuedWork*'
    OR s.name GLOB '*waitToFinish*'
    OR s.name GLOB '*sqlite*'
    OR s.name GLOB '*SQLiteDatabase*'
    OR s.name GLOB '*openFile*'
    OR s.name GLOB '*fsync*'
  GROUP BY fl.frame_key, fl.frame_start
),
-- BATCH_FRAME_IDENTITY_FILE_IO_CTE_END
-- 10i. Input event 与帧关联（android.input stdlib，按 FrameTimeline name/frame_id 对齐）。
-- input_data_fallback_view 会在 stdlib 缺失时创建同 schema 空视图，因此本查询
-- 既能使用真实 input 事件，也不会破坏基础帧根因分析。
per_frame_input_events AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    COUNT(*) as input_event_count,
    SUM(CASE WHEN ie.event_action = 'MOVE' THEN 1 ELSE 0 END) as input_move_count,
    ROUND(MAX(ie.handling_latency_dur) / 1e6, 2) as input_handling_ms,
    ROUND(SUM(ie.handling_latency_dur) / 1e6, 2) as input_handling_total_ms,
    ROUND(MAX(ie.dispatch_latency_dur) / 1e6, 2) as input_dispatch_ms,
    ROUND(MAX(ie.ack_latency_dur) / 1e6, 2) as input_ack_ms,
    ROUND(MAX(ie.total_latency_dur) / 1e6, 2) as input_total_ms,
    -- Input→Present: exact association only (see fragments/android_input_events_normalized.sql); NULL = unmeasured.
    ROUND(MAX(ie.exact_end_to_end_latency_dur) / 1e6, 2) as input_e2e_ms,
    SUM(CASE WHEN ie.frame_association = 'speculative' THEN 1 ELSE 0 END) as input_speculative_events,
    COUNT(ie.exact_frame_id) as input_exact_events
  FROM jank_frame_list fl
  JOIN android_input_events_normalized ie ON ie.upid = fl.upid
    AND fl.timeline_frame_id IS NOT NULL
    AND ie.frame_id = fl.timeline_frame_id
  GROUP BY fl.frame_key, fl.frame_start
),
-- 10j. Atrace-backed input stage slices overlapping the janky frame.
per_frame_input_stage_totals AS (
  SELECT
    fl.frame_key,
    fl.frame_start,
    CASE
      WHEN s.name GLOB '*deliverInputEvent*' THEN 'deliverInputEvent'
      WHEN s.name GLOB '*processInputEventForCompatibility*' THEN 'processInputEventForCompatibility'
      WHEN s.name GLOB '*dispatchTouchEvent*' THEN 'dispatchTouchEvent'
      WHEN s.name GLOB '*onInterceptTouchEvent*' THEN 'onInterceptTouchEvent'
      WHEN s.name GLOB '*onTouchEvent*' THEN 'onTouchEvent'
      WHEN s.name GLOB '*InputConsumer*' THEN 'InputConsumer'
      WHEN s.name GLOB '*RV Prefetch*' OR s.name GLOB '*RecyclerView*Prefetch*' THEN 'RecyclerView Prefetch'
      ELSE 'input'
    END as input_stage,
    ROUND(SUM(
      MAX(MIN(s.ts + s.dur, fl.frame_end) - MAX(s.ts, fl.frame_start), 0)
    ) / 1e6, 2) as input_slice_ms,
    COUNT(*) as input_slice_count,
    ROUND(MAX(s.dur) / 1e6, 2) as input_slice_max_ms
  FROM jank_frame_list fl
  JOIN per_frame_thread_roles ptr ON ptr.frame_key = fl.frame_key AND ptr.role = 'main'
  JOIN thread_track tt ON tt.utid = ptr.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < fl.frame_end
    AND s.ts + s.dur > fl.frame_start
    AND s.dur >= 100000
  WHERE s.name GLOB '*deliverInputEvent*'
    OR s.name GLOB '*processInputEventForCompatibility*'
    OR s.name GLOB '*dispatchTouchEvent*'
    OR s.name GLOB '*onInterceptTouchEvent*'
    OR s.name GLOB '*onTouchEvent*'
    OR s.name GLOB '*InputConsumer*'
    OR s.name GLOB '*RV Prefetch*'
    OR s.name GLOB '*RecyclerView*Prefetch*'
  GROUP BY fl.frame_key, fl.frame_start, input_stage
),
per_frame_input_slices AS (
  SELECT
    frame_key,
    frame_start,
    input_stage,
    input_slice_ms,
    input_slice_count,
    input_slice_max_ms
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY frame_key ORDER BY input_slice_ms DESC) as rn
    FROM per_frame_input_stage_totals
  )
  WHERE rn = 1
),
per_frame_input_detail AS (
  SELECT frame_key, frame_start,
    json_group_array(json_object(
      'action', event_action,
      'channel', normalized_event_channel,
      'handling_ms', handling_ms,
      'dispatch_ms', dispatch_ms,
      'ack_ms', ack_ms,
      'total_ms', total_ms,
      'e2e_ms', e2e_ms,
      'speculative', speculative,
      'input_ts', input_ts
    )) as input_events_json
  FROM (
    SELECT
      fl.frame_key,
      fl.frame_start,
      ie.event_action,
      ie.normalized_event_channel,
      ROUND(ie.handling_latency_dur / 1e6, 2) as handling_ms,
      ROUND(ie.dispatch_latency_dur / 1e6, 2) as dispatch_ms,
      ROUND(ie.ack_latency_dur / 1e6, 2) as ack_ms,
      ROUND(ie.total_latency_dur / 1e6, 2) as total_ms,
      ROUND(ie.exact_end_to_end_latency_dur / 1e6, 2) as e2e_ms,
      CASE WHEN ie.frame_association = 'speculative' THEN 1 ELSE 0 END as speculative,
      printf('%d', ie.dispatch_ts) as input_ts,
      ROW_NUMBER() OVER (PARTITION BY fl.frame_key ORDER BY ie.handling_latency_dur DESC) as rn
    FROM jank_frame_list fl
    JOIN android_input_events_normalized ie ON ie.upid = fl.upid
      AND fl.timeline_frame_id IS NOT NULL
      AND ie.frame_id = fl.timeline_frame_id
  )
  WHERE rn <= 5
  GROUP BY frame_key, frame_start
),
per_frame_input_slice_detail AS (
  SELECT frame_key, frame_start,
    json_group_array(json_object(
      'stage', input_stage,
      'overlap_ms', input_slice_ms,
      'count', input_slice_count,
      'max_ms', input_slice_max_ms
    )) as input_slices_json
  FROM per_frame_input_stage_totals
  GROUP BY frame_key, frame_start
),
per_frame_system_evidence AS (
  SELECT frame_key,json_group_array(json_object(
    'upid',upid,'utid',utid,'role',role,'window_start_ts',window_start_ts,'window_end_ts',window_end_ts,
    'state_covered_ns',state_covered_ns,'running_ns',running_ns,'runnable_ns',runnable_ns,
    'unknown_running_ns',unknown_running_ns,'uninterruptible_ns',uninterruptible_ns,
    'sleeping_ns',sleeping_ns,'other_state_ns',other_state_ns,
    'state_coverage',CASE WHEN state_covered_ns>window_end_ts-window_start_ts THEN 'invalid_overlap'
      WHEN state_covered_ns<window_end_ts-window_start_ts THEN 'partial' ELSE 'observed' END
  )) AS system_evidence_json
  FROM (
    SELECT window_id AS frame_key,upid,utid,role,window_start_ts,window_end_ts,SUM(dur_ns) AS state_covered_ns,
      SUM(CASE WHEN state='Running' THEN dur_ns ELSE 0 END) AS running_ns,
      SUM(CASE WHEN state IN ('R','R+') THEN dur_ns ELSE 0 END) AS runnable_ns,
      SUM(CASE WHEN state='Running' AND core_type='unknown' THEN dur_ns ELSE 0 END) AS unknown_running_ns,
      SUM(CASE WHEN state IN ('D','DK') THEN dur_ns ELSE 0 END) AS uninterruptible_ns,
      SUM(CASE WHEN state IN ('S','I') THEN dur_ns ELSE 0 END) AS sleeping_ns,
      SUM(CASE WHEN state NOT IN ('Running','R','R+','D','DK','S','I') THEN dur_ns ELSE 0 END) AS other_state_ns
    FROM frame_system_states GROUP BY window_id,upid,utid,role,window_start_ts,window_end_ts
  ) GROUP BY frame_key
),
-- ========== 11. 综合分析 ==========
analysis AS (
  SELECT
    fl.frame_key,
    fl.display_frame_token,
    fl.surface_frame_token,
    fl.layer_name,
    fl.frame_start,
    fl.frame_end,
    fl.dur_ms,
    fl.jank_type,
    fl.jank_responsibility,
    fl.session_id,
    fl.pid,
    fl.process_name,
    fl.frame_index,
    fl.vsync_missed,
    fl.present_interval_ms,
    COALESCE(ts.slice_name, '') as top_slice_name,
    COALESCE(ts.slice_dur_ms, 0) as top_slice_ms,
    COALESCE(ts.slice_offset_ms, 0) as top_slice_offset_ms,
    pcm.little_run_pct as little_run_pct,
    pcm.big_run_pct as big_run_pct,
    pcm.runnable_pct as runnable_pct,
    pfq.q1_pct as main_q1_pct,
    pfq.q2_pct as main_q2_pct,
    pfq.q3_pct as main_q3_pct,
    pfq.q4a_pct as main_q4a_pct,
    pfq.q4b_pct as main_q4b_pct,
    rtq.render_q1_pct as render_q1_pct,
    rtq.render_q2_pct as render_q2_pct,
    rtq.render_q3_pct as render_q3_pct,
    rtq.render_q4a_pct as render_q4a_pct,
    rtq.render_q4b_pct as render_q4b_pct,
    pff.big_avg_freq_mhz as big_avg_freq_mhz,
    pff.big_max_freq_mhz as big_max_freq_mhz,
    pfr.ramp_to_high_ms,
    cov.freq_ramp_evidence,
    COALESCE(pfb.binder_overlap_ms, 0) as binder_overlap_ms,
    COALESCE(pfgc.gc_overlap_ms, 0) as gc_overlap_ms,
    COALESCE(pfgc.gc_count, 0) as gc_count,
    COALESCE(gf.max_fence_dur_ns, 0) as max_fence_dur_ns,
    COALESCE(gf.total_fence_dur_ns, 0) as total_fence_dur_ns,
    COALESCE(sp.shader_count, 0) as shader_count,
    COALESCE(sp.total_shader_dur_ns, 0) as total_shader_dur_ns,
    tc.vsync_period_ns,
    tc.vsync_source,
    tc.frame_budget_ms,
    tc.slice_critical_ms,
    tc.freq_ramp_critical_ms,
    tc.binder_overlap_critical_ms,
    COALESCE(pfcc.cpu_freq_clusters_json, '[]') as cpu_freq_clusters_json,
    COALESCE(pffc.freq_timeline_json, '[]') as freq_timeline_json,
    COALESCE(pfmts.main_slices_json, '[]') as main_slices_json,
    COALESCE(pfrts.render_slices_json, '[]') as render_slices_json,
    COALESCE(pfbd.binder_calls_json, '[]') as binder_calls_json,
    COALESCE(pfgd.gc_events_json, '[]') as gc_events_json,
    COALESCE(pfld.lock_contention_json, '[]') as lock_contention_json,
    COALESCE(pfld.lock_contention_ms, 0) as lock_contention_ms,
    COALESCE(pfrsw.render_sync_wait_ms, 0) as render_sync_wait_ms,
    COALESCE(pfrswk.render_sync_rt_work_ms, 0) as render_sync_rt_work_ms,
    COALESCE(pfio.file_io_overlap_ms, 0) as file_io_overlap_ms,
    COALESCE(pfie.input_event_count, 0) as input_event_count,
    COALESCE(pfie.input_move_count, 0) as input_move_count,
    COALESCE(pfie.input_handling_ms, pfis.input_slice_max_ms, 0) as input_handling_ms,
    COALESCE(pfie.input_handling_total_ms, pfis.input_slice_ms, 0) as input_handling_total_ms,
    COALESCE(pfie.input_dispatch_ms, 0) as input_dispatch_ms,
    COALESCE(pfie.input_ack_ms, 0) as input_ack_ms,
    COALESCE(pfie.input_total_ms, 0) as input_total_ms,
    pfie.input_e2e_ms as input_e2e_ms,
    COALESCE(pfie.input_speculative_events, 0) as input_speculative_events,
    COALESCE(pfie.input_exact_events, 0) as input_exact_events,
    COALESCE(pfis.input_slice_ms, 0) as input_slice_ms,
    COALESCE(pfis.input_slice_count, 0) as input_slice_count,
    COALESCE(pfis.input_slice_max_ms, 0) as input_slice_max_ms,
    COALESCE(pfis.input_stage, '') as input_stage,
    COALESCE(pfid.input_events_json, '[]') as input_events_json,
    COALESCE(pfisd.input_slices_json, '[]') as input_slices_json,
    COALESCE(pfse.system_evidence_json, '[]') AS system_evidence_json,
    dpf.device_peak_freq_mhz,
    flm.freq_limit_state,
    flm.freq_limit_basis,
    flm.freq_limit_onset_confirmed,
    flm.freq_limit_onset_ts,
    flm.freq_limit_cooling_basis,
    flm.policy_cpu AS freq_limit_policy_cpu,
    ROUND(flm.limit_khz / 1000.0, 1) AS freq_limit_mhz,
    flm.depth_pct AS freq_limit_depth_pct,
    flm.binding_ratio AS freq_limit_binding_ratio,
    flm.onset_binding_ns AS freq_limit_onset_binding_ns,
    flm.binding_ns AS freq_limit_binding_ns,
    flm.run_ns AS freq_limit_run_ns,
    flm.trace_episode_id AS freq_limit_trace_episode_id,
    flr.freq_limit_state AS rt_freq_limit_state,
    flr.binding_ns AS rt_freq_limit_binding_ns,
    flr.policy_cpu AS rt_freq_limit_policy_cpu
  FROM jank_frame_list fl
  CROSS JOIN timing_config tc
  CROSS JOIN device_peak_freq dpf
  LEFT JOIN system_cpu_freq_limit_frame_binding flm ON flm.window_id=fl.frame_key AND flm.role='main'
  LEFT JOIN system_cpu_freq_limit_frame_binding flr ON flr.window_id=fl.frame_key AND flr.role='render'
  LEFT JOIN per_frame_system_evidence pfse ON pfse.frame_key=fl.frame_key
  LEFT JOIN top_slices ts ON ts.frame_key = fl.frame_key
  LEFT JOIN per_frame_cpu_mix pcm ON pcm.frame_key = fl.frame_key
  LEFT JOIN per_frame_quadrants pfq ON pfq.frame_key = fl.frame_key
  LEFT JOIN render_thread_quadrants rtq ON rtq.frame_key = fl.frame_key
  LEFT JOIN per_frame_freq pff ON pff.frame_key = fl.frame_key
  LEFT JOIN per_frame_ramp pfr ON pfr.frame_key = fl.frame_key
  LEFT JOIN system_cpu_big_freq_coverage cov ON cov.window_id = fl.frame_key
  LEFT JOIN per_frame_binder pfb ON pfb.frame_key = fl.frame_key
  LEFT JOIN per_frame_gc pfgc ON pfgc.frame_key = fl.frame_key
  LEFT JOIN gpu_fence_per_frame gf ON gf.frame_key = fl.frame_key
  LEFT JOIN shader_per_frame sp ON sp.frame_key = fl.frame_key
  LEFT JOIN per_frame_cpu_clusters pfcc ON pfcc.frame_key = fl.frame_key
  LEFT JOIN per_frame_freq_changes pffc ON pffc.frame_key = fl.frame_key
  LEFT JOIN per_frame_main_top_slices pfmts ON pfmts.frame_key = fl.frame_key
  LEFT JOIN per_frame_render_top_slices pfrts ON pfrts.frame_key = fl.frame_key
  LEFT JOIN per_frame_binder_detail pfbd ON pfbd.frame_key = fl.frame_key
  LEFT JOIN per_frame_gc_detail pfgd ON pfgd.frame_key = fl.frame_key
  LEFT JOIN per_frame_lock_detail pfld ON pfld.frame_key = fl.frame_key
  LEFT JOIN per_frame_render_sync_wait pfrsw ON pfrsw.frame_key = fl.frame_key
  LEFT JOIN per_frame_render_sync_work pfrswk ON pfrswk.frame_key = fl.frame_key
  LEFT JOIN per_frame_file_io pfio ON pfio.frame_key = fl.frame_key
  LEFT JOIN per_frame_input_events pfie ON pfie.frame_key = fl.frame_key
  LEFT JOIN per_frame_input_slices pfis ON pfis.frame_key = fl.frame_key
  LEFT JOIN per_frame_input_detail pfid ON pfid.frame_key = fl.frame_key
  LEFT JOIN per_frame_input_slice_detail pfisd ON pfisd.frame_key = fl.frame_key
),
-- ========== 11. 根因分类（direct-evidence 与限频两族与 jank_frame_detail 对齐） ==========
classified AS (
  SELECT *,
    CASE
      -- P0: 保留 Buffer Stuffing 标签分类；此分支没有独立验证背压机制。
      -- 不能凭标签排除 App、锁或 Binder；需核验呈现节奏与 dequeue/release-fence。
      WHEN jank_responsibility = 'BUFFER_STUFFING'
        THEN 'buffer_stuffing'
      -- P0.5: SF 责任按 Perfetto FrameTimeline 的直接类型细分。
      WHEN jank_responsibility = 'SF' AND jank_type GLOB '*SurfaceFlinger*'
        THEN 'sf_composition_slow'
      WHEN jank_responsibility = 'SF' AND jank_type GLOB '*Display HAL*'
        THEN 'display_hal'
      WHEN jank_responsibility = 'SF' AND jank_type GLOB '*Prediction Error*'
        THEN 'prediction_error'
      WHEN jank_responsibility = 'SF'
        THEN 'sf_composition_slow'
      -- P1: Binder 同步阻塞（top slice 内有大量同步 Binder 重叠）
      WHEN top_slice_ms > slice_critical_ms AND binder_overlap_ms >= binder_overlap_critical_ms
        THEN 'binder_sync_blocking'
      -- P1.25: 主线程 monitor contention 与当前帧有直接重叠。
      WHEN lock_contention_ms > 0.2
        THEN 'lock_contention'
      -- P1.5: GC 暂停（帧窗口内 GC 重叠 > 1ms）
      WHEN gc_overlap_ms > 1.0
        THEN 'gc_jank'
      -- P1.6: GC 压力级联 — 帧窗口内多次 GC（>=3 次），内存压力高
      -- 即使单次 GC 重叠 <1ms，密集 GC 累积也会显著影响帧耗时
      WHEN gc_count >= 3 AND gc_overlap_ms > 0.5
        THEN 'gc_pressure_cascade'
      -- P1.7: App input stage 慢。只使用 App 责任/隐形掉帧帧；android.input
      -- handling 或主线程 input slice 都可作为直接证据，同帧事件堆积只是辅助信号
      -- （只计精确帧关联）。
      WHEN jank_responsibility IN ('APP', 'HIDDEN')
        AND (
          input_handling_ms > frame_budget_ms * ${input_handling_budget_ratio|0.5}
          OR input_slice_ms > frame_budget_ms * ${input_handling_budget_ratio|0.5}
          OR (
            input_exact_events >= ${input_event_backlog_threshold|3}
            AND input_handling_ms > frame_budget_ms * 0.25
          )
        )
        THEN 'input_handling_slow'
      -- P2: 小核调度（top slice 多数时间在小核执行）
      WHEN top_slice_ms > slice_critical_ms AND little_run_pct >= 45
        THEN 'small_core_placement'
      -- P3: 关键操作中调度延迟（top slice 中 Runnable 等待占比高）
      WHEN top_slice_ms > slice_critical_ms AND runnable_pct >= 15
        THEN 'sched_delay_in_slice'
      -- P3.5: Shader 编译（RenderThread 有 shader compile 且耗时 > 30% 帧预算）
      WHEN shader_count > 0 AND total_shader_dur_ns > vsync_period_ns * 0.3
        THEN 'shader_compile'
      -- P3.6: GPU fence 等待（RenderThread 长时间等待 GPU fence > 50% 帧预算）
      WHEN max_fence_dur_ns > vsync_period_ns * 0.5
        THEN 'gpu_fence_wait'
      -- P3.7: RenderThread 负载过重 — RT 主动运行占比高（>70%），非 GPU/Shader 等待
      -- 到达此处说明 Shader/GPU fence 已排除；RT 自身计算密集是瓶颈
      WHEN (render_q1_pct + render_q2_pct) > 70 AND render_q4b_pct < 20
        THEN 'render_thread_heavy'
      -- P4: 重度业务负载（>2× 帧预算，即使满频也会超时）
      WHEN top_slice_ms > frame_budget_ms * 2.0
        THEN 'workload_heavy'
      -- P4.5: 温控限频 — 主线程 top slice 的运行时间受 policy 频率上限约束
      -- （freq_limit_state = capped_binding），且约束它的那个上限值由与该 policy
      -- 时序关联的散热设备升档写入（该值自身的 onset verdict 为 confirmed，且不是
      -- 靠多个上限值拼出的约束）。放在 workload_heavy 之后：供给侧约束仅在无更强
      -- 直接原因时才作为主因。频率比设备峰值低不是限频证据，不参与判定。
      WHEN top_slice_ms > slice_critical_ms AND freq_limit_state = 'capped_binding'
        AND freq_limit_onset_confirmed = 1 AND freq_limit_basis <> 'mixed_limit_values_in_frame'
        THEN 'thermal_throttling'
      -- P4.6: CPU 最大频率被限 — 上限约束了主线程，但该上限值的触发方未由帧内
      -- 证据确定（放宽后的值、写入时刻不可观测、未配对的收紧、多值拼接等）。
      WHEN top_slice_ms > slice_critical_ms AND freq_limit_state = 'capped_binding'
        THEN 'cpu_max_limited'
      -- P5: 大核低频（边际情况：slice 在 1x-2x 帧预算区间）
      WHEN top_slice_ms > slice_critical_ms AND big_run_pct >= 40
        AND big_avg_freq_mhz > 0 AND big_max_freq_mhz > 0
        AND big_avg_freq_mhz < big_max_freq_mhz * 0.55
        THEN 'big_core_low_freq'
      -- P6: 频率爬升慢（边际情况：slice 在 1x-2x 帧预算区间），且整帧每个大核都有频率观测
      WHEN top_slice_ms > slice_critical_ms
        AND freq_ramp_evidence = 'observed'
        AND ramp_to_high_ms > freq_ramp_critical_ms
        AND top_slice_offset_ms <= ramp_to_high_ms
        THEN 'freq_ramp_slow'
      -- ========== 四象限/IO/Binder 信号（不依赖 top_slice_ms 阈值）==========
      -- P7: CPU 全核饱和 — 双线程同时调度等待高
      WHEN main_q3_pct > 15 AND render_q3_pct > 15
        THEN 'cpu_saturation'
      -- P7.5: 调度延迟（仅主线程 Runnable 高）
      WHEN main_q3_pct > 20
        THEN 'scheduling_delay'
      -- P8: 主线程文件 IO — SharedPreferences/SQLite/fsync 等具体 IO slice
      WHEN file_io_overlap_ms > 1.0
        THEN 'main_thread_file_io'
      -- P8.5: 不可中断等待（D/DK 状态；IO 归因需 io_wait/blocked_function）
      WHEN main_q4a_pct > 20
        THEN 'uninterruptible_wait'
      -- P9: Binder 超时 — 帧窗口内 Binder 累计 >500ms
      WHEN binder_overlap_ms > 500
        THEN 'binder_timeout'
      -- P9.5: 只有 material HWUI 同步等待且 RenderThread 同窗活跃时，
      -- 才把同步依赖提升为主 reason；很短的 postAndWait 只保留为放大证据。
      WHEN main_q4b_pct > 30
        AND render_sync_wait_ms >= MAX(frame_budget_ms * 0.20, dur_ms * 0.25)
        AND (
          (render_q1_pct + render_q2_pct) >= 30
          OR render_sync_rt_work_ms > 0
        )
        THEN 'render_sync_wait'
      -- P10: 小核调度（按四象限判断）
      WHEN main_q2_pct > 50
        THEN 'small_core_placement'
      -- ========== 兜底分类 ==========
      -- P11: 工作负载超时兜底（top_slice > critical 但无特定供给侧/四象限因素）
      WHEN top_slice_ms > slice_critical_ms
        THEN 'workload_heavy'
      -- FrameTimeline 已确认 App 责任，但当前帧没有足够直接证据继续命名底层原因。
      WHEN jank_responsibility = 'APP'
        THEN 'app_jank_unattributed'
      -- FrameTimeline 自身只给出 Unknown Jank，且上述直接机制探针均未命中。
      -- 这是保留用户可见异常、但明确停止猜测根因的证据边界。
      WHEN jank_responsibility = 'UNKNOWN' AND jank_type GLOB '*Unknown Jank*'
        THEN 'frame_timeline_unattributed'
      ELSE 'unknown'
    END as reason_code
  FROM analysis
)
SELECT
  CAST(display_frame_token AS TEXT) as frame_id,
  CASE
    WHEN frame_key GLOB 'display:*' THEN CAST(display_frame_token AS TEXT)
    ELSE frame_key
  END as frame_identity_key,
  layer_name,
  frame_index,
  printf('%d', frame_start) as start_ts,
  printf('%d', frame_end - frame_start) as dur,
  dur_ms,
  jank_type,
  vsync_missed,
  present_interval_ms,
  jank_responsibility,
  pid,
  process_name,
  reason_code,
  '${buffer_tx_coverage.data[0].coverage_status}' as frame_timeline_coverage_status,
  ${buffer_tx_coverage.data[0].frame_timeline_to_buffer_tx_ratio} as frame_timeline_to_buffer_tx_ratio,
  CASE
    WHEN '${buffer_tx_coverage.data[0].coverage_status}' = 'partial_frame_timeline_coverage'
      THEN 'partial_sample'
    WHEN '${buffer_tx_coverage.data[0].coverage_status}' = 'no_buffer_tx_candidate'
      THEN 'frame_timeline_only_unbenchmarked'
    ELSE 'full_frame_timeline'
  END as evidence_scope,
  scope.root_cause_eligible_frame_count,
  scope.root_cause_analyzed_frame_count,
  scope.root_cause_coverage_ratio,
  scope.root_cause_sample_limit_per_session,
  scope.root_cause_analysis_scope,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN '原始 Buffer Stuffing 标签，帧耗时 ' || dur_ms || 'ms；呈现间隔异常候选，需用 presentation_cadence_audit 与 dequeue/release-fence 核验；尚未证明 BufferQueue 背压，也不能排除 App 原因'
    WHEN reason_code = 'sf_composition_slow' THEN 'SF合成超时: SurfaceFlinger 侧导致掉帧（非 App 问题），帧耗时 ' || dur_ms || 'ms'
    WHEN reason_code = 'display_hal' THEN 'Display HAL 延迟: SurfaceFlinger 已按时下发，但该帧未在目标 VSync 呈现（非 App 根因）'
    WHEN reason_code = 'prediction_error' THEN 'FrameTimeline 预测误差: SurfaceFlinger scheduler 的预测呈现时间发生漂移；孤立事件通常不代表用户可感知 App 卡顿'
    WHEN reason_code = 'app_jank_unattributed' THEN 'App Deadline Missed 已确认，但当前帧缺少 Binder/GC/锁/Input/调度等直接证据，底层原因保持未归因'
    WHEN reason_code = 'frame_timeline_unattributed' THEN 'FrameTimeline 标记为 Unknown Jank；当前 trace 没有 App、SF 或帧内直接机制证据，异常保留但根因未归因'
    WHEN reason_code = 'thermal_throttling' THEN '温控限频: "' || top_slice_name || '" 运行 ' || ROUND(freq_limit_run_ns / 1e6, 2) || 'ms 中有 ' || ROUND(freq_limit_onset_binding_ns / 1e6, 2) || 'ms 受 policy' || freq_limit_policy_cpu || ' 上限 ' || freq_limit_mhz || 'MHz 约束（低于观测最高上限 ' || freq_limit_depth_pct || '%，运行频率/上限 ' || freq_limit_binding_ratio || '）；该上限值由与该 policy 时序关联的散热设备升档写入' || CASE WHEN freq_limit_binding_ns > freq_limit_onset_binding_ns THEN '；跨全部上限值共受约束 ' || ROUND(freq_limit_binding_ns / 1e6, 2) || 'ms' ELSE '' END
    WHEN reason_code = 'binder_sync_blocking' THEN '同步Binder阻塞: "' || top_slice_name || '" 中 Binder 重叠 ' || binder_overlap_ms || 'ms'
    WHEN reason_code = 'lock_contention' THEN 'Monitor锁竞争: 主线程在帧窗口内直接等待 ' || lock_contention_ms || 'ms'
    WHEN reason_code = 'render_sync_wait' THEN 'UI→RenderThread同步等待: 主线程 postAndWait/syncFrameState 重叠 ' || render_sync_wait_ms || 'ms'
    WHEN reason_code = 'gc_jank' THEN 'GC暂停: 帧窗口内 GC 重叠 ' || gc_overlap_ms || 'ms (' || gc_count || ' 次)'
    WHEN reason_code = 'gc_pressure_cascade' THEN 'GC压力级联: 帧窗口内 ' || gc_count || ' 次 GC，总重叠 ' || gc_overlap_ms || 'ms（内存压力高）'
    WHEN reason_code = 'input_handling_slow' THEN '输入处理阻塞: ' || COALESCE(NULLIF(input_stage, ''), 'input') || ' 与帧窗口重叠 ' || input_slice_ms || 'ms，最长相关 slice ' || input_handling_ms || 'ms（预算 ' || frame_budget_ms || 'ms）'
    WHEN reason_code = 'small_core_placement' THEN '小核调度: "' || top_slice_name || '" 小核占比 ' || little_run_pct || '%'
    WHEN reason_code = 'sched_delay_in_slice' THEN '调度延迟: "' || top_slice_name || '" Runnable 占比 ' || runnable_pct || '%'
    WHEN reason_code = 'shader_compile' THEN 'Shader编译: ' || shader_count || ' 次编译，总计 ' || ROUND(total_shader_dur_ns / 1e6, 2) || 'ms'
    WHEN reason_code = 'gpu_fence_wait' THEN 'GPU Fence等待: 最长 ' || ROUND(max_fence_dur_ns / 1e6, 2) || 'ms'
    WHEN reason_code = 'render_thread_heavy' THEN 'RT负载过重: RenderThread 运行占比 ' || (render_q1_pct + render_q2_pct) || '%, 等待仅 ' || render_q4b_pct || '%'
    WHEN reason_code = 'workload_heavy' THEN '负载过重: "' || top_slice_name || '" 耗时 ' || top_slice_ms || 'ms (预算 ' || frame_budget_ms || 'ms)'
    WHEN reason_code = 'cpu_max_limited' THEN 'CPU限频生效: "' || top_slice_name || '" 运行 ' || ROUND(freq_limit_run_ns / 1e6, 2) || 'ms 中有 ' || ROUND(freq_limit_onset_binding_ns / 1e6, 2) || 'ms 受 policy' || freq_limit_policy_cpu || ' 上限 ' || freq_limit_mhz || 'MHz 约束（低于观测最高上限 ' || freq_limit_depth_pct || '%，运行频率/上限 ' || freq_limit_binding_ratio || '）' || CASE WHEN freq_limit_binding_ns > freq_limit_onset_binding_ns THEN '；跨全部上限值共受约束 ' || ROUND(freq_limit_binding_ns / 1e6, 2) || 'ms' ELSE '' END || '；触发方未由帧内证据确定（' || COALESCE(freq_limit_basis, 'onset_unclassified') || '）'
    WHEN reason_code = 'big_core_low_freq' THEN '大核低频: 平均 ' || big_avg_freq_mhz || 'MHz (峰值 ' || big_max_freq_mhz || 'MHz)'
    WHEN reason_code = 'freq_ramp_slow' THEN '升频慢: ' || ramp_to_high_ms || 'ms 才达高频'
    WHEN reason_code = 'scheduling_delay' THEN '调度等待: Q3=' || main_q3_pct || '%'
    WHEN reason_code = 'cpu_saturation' THEN 'CPU全核饱和: 主线程 Q3=' || main_q3_pct || '%, RT Q3=' || render_q3_pct || '%（双线程同时调度等待）'
    WHEN reason_code = 'uninterruptible_wait' THEN '不可中断等待: Q4a(D/DK)=' || main_q4a_pct || '%；IO 归因需 io_wait/blocked_function'
    WHEN reason_code = 'main_thread_file_io' THEN '主线程文件IO: 帧内 IO overlap ' || file_io_overlap_ms || 'ms (SharedPreferences/SQLite/fsync)'
    WHEN reason_code = 'binder_timeout' THEN 'Binder超时: 帧内 Binder 累计 ' || binder_overlap_ms || 'ms (>500ms)'
    ELSE '未分类 (帧耗时 ' || dur_ms || 'ms)'
  END as primary_cause,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN '高'
    WHEN reason_code = 'sf_composition_slow' THEN '高'
    WHEN reason_code = 'display_hal' THEN '高'
    WHEN reason_code = 'prediction_error' THEN '高'
    WHEN reason_code = 'app_jank_unattributed' THEN '中'
    WHEN reason_code = 'frame_timeline_unattributed' THEN '低'
    WHEN reason_code = 'thermal_throttling' THEN '高'
    WHEN reason_code = 'gc_pressure_cascade' THEN '高'
    WHEN reason_code = 'input_handling_slow' THEN '高'
    WHEN reason_code = 'render_thread_heavy' THEN '中'
    WHEN reason_code = 'cpu_max_limited' THEN '中'
    WHEN reason_code = 'cpu_saturation' THEN '中'
    WHEN reason_code = 'main_thread_file_io' THEN '高'
    WHEN reason_code = 'binder_timeout' THEN '高'
    WHEN reason_code = 'lock_contention' THEN '高'
    WHEN reason_code = 'render_sync_wait' THEN '中'
    WHEN top_slice_ms > slice_critical_ms THEN '高'
    WHEN shader_count > 0 THEN '高'
    WHEN max_fence_dur_ns > vsync_period_ns * 0.5 THEN '中'
    WHEN gc_overlap_ms > 1.0 THEN '高'
    WHEN main_q3_pct > 20 OR main_q4a_pct > 20 THEN '中'
    ELSE '低'
  END as confidence,
  top_slice_name,
  top_slice_ms,
  -- MainThread 四象限完整输出
  main_q1_pct,
  main_q2_pct,
  main_q3_pct,
  main_q4a_pct,
  main_q4b_pct,
  -- RenderThread 四象限
  COALESCE(render_q1_pct, 0) as render_q1_pct,
  COALESCE(render_q2_pct, 0) as render_q2_pct,
  COALESCE(render_q3_pct, 0) as render_q3_pct,
  COALESCE(render_q4a_pct, 0) as render_q4a_pct,
  COALESCE(render_q4b_pct, 0) as render_q4b_pct,
  -- CPU 频率
  big_avg_freq_mhz,
  big_max_freq_mhz,
  ramp_to_high_ms as ramp_ms,
  freq_ramp_evidence,
  -- Top Slice CPU 分布
  little_run_pct as top_slice_little_pct,
  big_run_pct as top_slice_big_pct,
  runnable_pct as top_slice_runnable_pct,
  -- GPU / Shader
  ROUND(max_fence_dur_ns / 1e6, 2) as gpu_fence_ms,
  ROUND(total_fence_dur_ns / 1e6, 2) as gpu_fence_total_ms,
  shader_count,
  ROUND(total_shader_dur_ns / 1e6, 2) as shader_ms,
  -- Binder/GC
binder_overlap_ms,
lock_contention_ms,
render_sync_wait_ms,
render_sync_rt_work_ms,
gc_overlap_ms,
  gc_count,
  -- 帧预算参考
  frame_budget_ms,
  vsync_source,
  -- 设备峰值频率（观测列，不是硬件上限，也不是限频证据）
  device_peak_freq_mhz,
  ROUND(100.0 * big_max_freq_mhz / NULLIF(device_peak_freq_mhz, 0), 1) AS freq_ceiling_ratio_pct,
  -- 主线程 top slice 的频率上限约束（fragments/system_cpu_freq_limit_frame_binding.sql）
  freq_limit_state,
  freq_limit_basis,
  freq_limit_onset_confirmed,
  CASE WHEN freq_limit_onset_ts IS NOT NULL THEN printf('%d', freq_limit_onset_ts) END AS freq_limit_onset_ts,
  freq_limit_cooling_basis,
  freq_limit_policy_cpu,
  freq_limit_mhz,
  freq_limit_depth_pct,
  freq_limit_binding_ratio,
  freq_limit_onset_binding_ns,
  freq_limit_binding_ns,
  freq_limit_run_ns,
  freq_limit_trace_episode_id,
  -- RenderThread 的同一判定，仅供诊断，不进入 reason_code
  rt_freq_limit_state,
  rt_freq_limit_binding_ns,
  rt_freq_limit_policy_cpu,
  -- 文件 IO 重叠
  file_io_overlap_ms,
  -- Input pipeline 证据
  input_event_count,
  input_move_count,
  input_handling_ms,
  input_handling_total_ms,
  input_dispatch_ms,
  input_e2e_ms,
  input_slice_ms,
  input_stage,
  input_speculative_events,
  -- 批量详情 JSON 列（供展开行使用）
  cpu_freq_clusters_json,
  freq_timeline_json,
  main_slices_json,
  render_slices_json,
  binder_calls_json,
  gc_events_json,
  lock_contention_json,
  input_events_json,
  input_slices_json,
  system_evidence_json
FROM classified
CROSS JOIN root_cause_population scope
ORDER BY session_id, frame_start
