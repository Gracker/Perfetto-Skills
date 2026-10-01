-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/jank_frame_detail.skill.yaml
-- Source SHA-256: 62ecf72c4ed2df7a881eeff7e7c601aa36f9ea52c63236624afde55dbcd63ec5

-- 根因分析: 综合四象限、CPU频率、耗时操作等数据，输出明确的根因结论
-- CTEs vsync_ticks, vsync_config, target_threads, thread_states injected via sql_fragments
WITH
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
-- Fragment: target_threads
-- Resolves MainThread + RenderThread for the target package.
-- Supports standard Android (RenderThread), Flutter (N.raster/N.ui), and Compose.
-- Params: ${package}, ${start_ts}, ${end_ts}
-- Optional: ${main_start_ts}, ${main_end_ts}, ${render_start_ts}, ${render_end_ts}
target_threads AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid, p.name as process_name,
    CASE
      WHEN t.tid = p.pid THEN 'MainThread'
      WHEN t.name = 'RenderThread' THEN 'RenderThread'
      WHEN t.name GLOB '[0-9]*.raster' THEN 'RenderThread'
      WHEN t.name GLOB '[0-9]*.ui' THEN 'MainThread'
      ELSE 'Other'
    END as thread_type,
    CASE
      WHEN t.tid = p.pid THEN COALESCE(${main_start_ts}, ${start_ts})
      WHEN t.name = 'RenderThread' THEN COALESCE(${render_start_ts}, ${start_ts})
      WHEN t.name GLOB '[0-9]*.raster' THEN COALESCE(${render_start_ts}, ${start_ts})
      WHEN t.name GLOB '[0-9]*.ui' THEN COALESCE(${main_start_ts}, ${start_ts})
      ELSE ${start_ts}
    END as thread_start_ts,
    CASE
      WHEN t.tid = p.pid THEN COALESCE(${main_end_ts}, ${end_ts})
      WHEN t.name = 'RenderThread' THEN COALESCE(${render_end_ts}, ${end_ts})
      WHEN t.name GLOB '[0-9]*.raster' THEN COALESCE(${render_end_ts}, ${end_ts})
      WHEN t.name GLOB '[0-9]*.ui' THEN COALESCE(${main_end_ts}, ${end_ts})
      ELSE ${end_ts}
    END as thread_end_ts
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NULL OR p.upid = ${__process_scope.upid})
    AND (
      ${__process_scope.upid} IS NOT NULL
      OR '${package}' = ''
      OR p.name = '${package}'
      OR p.name GLOB '${package}:*'
    )
    AND (t.tid = p.pid OR t.name = 'RenderThread'
         OR t.name GLOB '[0-9]*.raster' OR t.name GLOB '[0-9]*.ui')
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- Compatibility fragment. Inputs: target_threads(utid,thread_type,
-- thread_start_ts,thread_end_ts). New consumers use system_thread_state_spans.
-- Q1 groups recorded big/medium capacity; Q2 is little only. Uniform/missing
-- capacity remains unknown. D/DK and S/I are observed waits, not root causes.
thread_states AS (
  SELECT thread_type, quadrant, SUM(dur_ns) AS dur_ns
  FROM (
    SELECT tt.thread_type,
      CASE
        WHEN ts.state='Running' AND c.capacity>0
          AND NOT EXISTS (SELECT 1 FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND (c2.capacity IS NULL OR c2.capacity<=0))
          AND c.capacity>(SELECT MIN(c2.capacity) FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND c2.capacity>0) THEN 'Q1'
        WHEN ts.state='Running' AND c.capacity>0
          AND NOT EXISTS (SELECT 1 FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND (c2.capacity IS NULL OR c2.capacity<=0))
          AND c.capacity=(SELECT MIN(c2.capacity) FROM cpu c2 WHERE c2.machine_id IS c.machine_id AND c2.capacity>0)
          AND c.capacity<(SELECT MAX(c2.capacity) FROM cpu c2 WHERE c2.machine_id IS c.machine_id) THEN 'Q2'
        WHEN ts.state='Running' THEN 'UnknownRunning'
        WHEN ts.state IN ('R','R+') THEN 'Q3'
        WHEN ts.state IN ('D','DK') THEN 'Q4a'
        WHEN ts.state IN ('S','I') THEN 'Q4b'
        ELSE 'Other' END AS quadrant,
      MIN(CASE WHEN ts.dur=-1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts+ts.dur END,tt.thread_end_ts)
        -MAX(ts.ts,tt.thread_start_ts) AS dur_ns
    FROM thread_state ts JOIN target_threads tt ON tt.utid=ts.utid
    LEFT JOIN cpu c ON c.id=ts.ucpu
    WHERE ts.dur>=-1 AND ts.dur!=0 AND ts.ts<tt.thread_end_ts
      AND CASE WHEN ts.dur=-1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts+ts.dur END>tt.thread_start_ts
  ) GROUP BY thread_type,quadrant
)
,
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)
-- This file is part of SmartPerfetto. See LICENSE for details.

-- Per-tier CPU cluster load over [${start_ts}, ${end_ts}], shared by
-- cpu_cluster_load_in_range and jank_frame_detail's root cause so their numbers
-- agree (cpu_load_in_range still reports its own per-machine sched measure).
-- Requires _cpu_topology: run the cpu_topology_view Skill first in the same
-- Skill. Denominator follows upstream
-- android_cpu_cluster_utilization_in_interval (7af4ec945c):
--   - every core of the tier in _cpu_topology, not only cores that ran a task
--     in the window (idle cores leaving the denominator overstate the load);
--   - awake time: to_monotonic excludes suspend; without a clock snapshot, or
--     when the result is out of range, the wall-clock duration is used.
-- Running time comes from thread_state, which carries no idle-thread rows; a
-- row still running at trace end (dur = -1) runs to the trace end.
cpu_cluster_awake AS (
  SELECT IIF(monotonic_ns > 0 AND monotonic_ns <= wall_ns, monotonic_ns, wall_ns) AS awake_ns
  FROM (
    SELECT
      ${end_ts} - ${start_ts} AS wall_ns,
      to_monotonic(${end_ts}) - to_monotonic(${start_ts}) AS monotonic_ns
  )
),
cpu_cluster_core_running AS (
  SELECT
    cpu,
    core_type,
    SUM(MIN(end_ts, ${end_ts}) - MAX(ts, ${start_ts})) AS running_ns
  FROM (
    SELECT
      ts.cpu,
      ct.core_type,
      ts.ts,
      IIF(ts.dur < 0, (SELECT end_ts FROM trace_bounds), ts.ts + ts.dur) AS end_ts
    FROM thread_state ts
    JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
    WHERE ts.ts < ${end_ts}
      AND (ts.dur < 0 OR ts.ts + ts.dur > ${start_ts})
      AND ts.state = 'Running'
      AND ts.cpu IS NOT NULL
  )
  WHERE end_ts > ${start_ts}
  GROUP BY cpu, core_type
),
-- One row per tier present in _cpu_topology (prime/big/medium/little/unknown).
cpu_cluster_load_by_tier AS (
  SELECT
    cc.core_type,
    cc.core_count,
    COUNT(r.cpu) AS active_core_count,
    a.awake_ns,
    COALESCE(SUM(r.running_ns), 0) AS running_ns,
    COALESCE(MAX(r.running_ns), 0) AS max_core_running_ns
  FROM (
    SELECT core_type, COUNT(DISTINCT cpu_id) AS core_count
    FROM _cpu_topology
    GROUP BY core_type
  ) cc
  CROSS JOIN cpu_cluster_awake a
  LEFT JOIN cpu_cluster_core_running r ON r.core_type = cc.core_type
  GROUP BY cc.core_type, cc.core_count, a.awake_ns
)
,
-- 3. 计算各线程四象限百分比
quadrant_pct AS (
  SELECT
    thread_type,
    quadrant,
    dur_ns,
    ROUND(100.0 * dur_ns / NULLIF(SUM(dur_ns) OVER (PARTITION BY thread_type), 0), 1) as pct
  FROM thread_states
  -- All observed states remain in the denominator, including unknown topology.
),
main_summary AS (
  SELECT
    COALESCE(SUM(CASE WHEN quadrant = 'Q1' THEN pct ELSE 0 END), 0) as q1,
    COALESCE(SUM(CASE WHEN quadrant = 'Q2' THEN pct ELSE 0 END), 0) as q2,
    COALESCE(SUM(CASE WHEN quadrant = 'Q3' THEN pct ELSE 0 END), 0) as q3,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4a' THEN pct ELSE 0 END), 0) as q4a,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4b' THEN pct ELSE 0 END), 0) as q4b
  FROM quadrant_pct WHERE thread_type = 'MainThread'
),
render_summary AS (
  SELECT
    COALESCE(SUM(CASE WHEN quadrant = 'Q1' THEN pct ELSE 0 END), 0) as q1,
    COALESCE(SUM(CASE WHEN quadrant = 'Q2' THEN pct ELSE 0 END), 0) as q2,
    COALESCE(SUM(CASE WHEN quadrant = 'Q3' THEN pct ELSE 0 END), 0) as q3,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4a' THEN pct ELSE 0 END), 0) as q4a,
    COALESCE(SUM(CASE WHEN quadrant = 'Q4b' THEN pct ELSE 0 END), 0) as q4b
  FROM quadrant_pct WHERE thread_type = 'RenderThread'
),
-- 4. 获取最耗时的主线程操作
main_thread_utid AS (
  SELECT t.utid
  FROM thread t JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.tid = p.pid OR t.name GLOB '[0-9]*.ui')
),
top_slice AS (
  SELECT
    s.name,
    s.ts as slice_ts,
    s.dur as slice_dur_ns,
    ROUND(s.dur / 1e6, 2) as dur_ms,
    tt.utid as slice_utid
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  WHERE tt.utid IN (SELECT utid FROM main_thread_utid)
    AND s.ts >= COALESCE(${main_start_ts}, ${start_ts})
    AND s.ts < COALESCE(${main_end_ts}, ${end_ts})
    AND s.dur >= 1000000
    AND s.name NOT GLOB '*resynced*'
  ORDER BY s.dur DESC
  LIMIT 1
),
top_slice_bounds AS (
  SELECT
    slice_ts as slice_start_ns,
    slice_ts + slice_dur_ns as slice_end_ns,
    slice_dur_ns,
    slice_utid
  FROM top_slice
),
monitor_lock_overlap AS (
  SELECT ROUND(COALESCE(SUM(
    MAX(
      MIN(amc.ts + amc.dur, ${end_ts}) - MAX(amc.ts, ${start_ts}),
      0
    )
  ), 0) / 1e6, 2) as lock_contention_ms
  FROM android_monitor_contention amc
  WHERE amc.ts < ${end_ts}
    AND amc.ts + amc.dur > ${start_ts}
    AND amc.is_blocked_thread_main = 1
    AND (${__process_scope.upid} IS NULL OR amc.upid = ${__process_scope.upid})
    AND (
      ${__process_scope.upid} IS NOT NULL
      OR '${package}' = ''
      OR amc.process_name = '${package}'
      OR amc.process_name GLOB '${package}:*'
    )
),
-- DEEP_RENDER_SYNC_CTES_BEGIN
render_sync_intervals AS (
  SELECT
    MAX(s.ts, ${start_ts}) as sync_start,
    MIN(s.ts + s.dur, ${end_ts}) as sync_end
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  WHERE tt.utid IN (SELECT utid FROM main_thread_utid)
    AND s.ts < ${end_ts}
    AND s.ts + s.dur > ${start_ts}
    AND (
      s.name GLOB '*postAndWait*'
      OR s.name GLOB '*syncAndDrawFrame*'
      OR s.name GLOB '*syncFrameState*'
    )
),
render_sync_ordered AS (
  SELECT
    *,
    MAX(sync_end) OVER (
      ORDER BY sync_start, sync_end
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) as previous_max_end
  FROM render_sync_intervals
  WHERE sync_end > sync_start
),
render_sync_labeled AS (
  SELECT
    *,
    SUM(
      CASE
        WHEN previous_max_end IS NULL OR sync_start > previous_max_end THEN 1
        ELSE 0
      END
    ) OVER (
      ORDER BY sync_start, sync_end
      ROWS UNBOUNDED PRECEDING
    ) as interval_group
  FROM render_sync_ordered
),
render_sync_union AS (
  SELECT
    interval_group,
    MIN(sync_start) as sync_start,
    MAX(sync_end) as sync_end
  FROM render_sync_labeled
  GROUP BY interval_group
),
render_sync_wait AS (
  SELECT ROUND(COALESCE(SUM(sync_end - sync_start), 0) / 1e6, 2) as render_sync_wait_ms
  FROM render_sync_union
),
-- DEEP_RENDER_SYNC_CTES_END
render_sync_rt_work AS (
  SELECT ROUND(COALESCE(MAX(
    MAX(MIN(s.ts + s.dur, ${end_ts}) - MAX(s.ts, ${start_ts}), 0)
  ), 0) / 1e6, 2) as render_sync_rt_work_ms
  FROM slice s
  JOIN thread_track track ON s.track_id = track.id
  JOIN target_threads target ON track.utid = target.utid
  WHERE target.thread_type = 'RenderThread'
    AND s.ts < ${end_ts}
    AND s.ts + s.dur > ${start_ts}
    AND (
      s.name GLOB '*syncFrameState*'
      OR s.name GLOB '*DrawFrame*'
    )
),
top_slice_state_overlap AS (
  SELECT
    ts.state,
    ts.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    (
      CASE
        WHEN (CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts + ts.dur END) < b.slice_end_ns THEN (CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts + ts.dur END)
        ELSE b.slice_end_ns
      END
      -
      CASE
        WHEN ts.ts > b.slice_start_ns THEN ts.ts
        ELSE b.slice_start_ns
      END
    ) as overlap_ns
  FROM thread_state ts
  JOIN main_thread_utid mtu ON ts.utid = mtu.utid
  JOIN top_slice_bounds b
  LEFT JOIN system_cpu_topology ct ON ts.ucpu = ct.ucpu
  WHERE ts.ts < b.slice_end_ns
    AND (CASE WHEN ts.dur = -1 THEN (SELECT end_ts FROM trace_bounds) ELSE ts.ts + ts.dur END) > b.slice_start_ns
),
top_slice_cpu_mix AS (
  SELECT
    ROUND(
      100.0 * SUM(CASE WHEN state = 'Running' AND core_type = 'little' AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as little_run_pct,
    ROUND(
      100.0 * SUM(CASE WHEN state = 'Running' AND core_type IN ('prime', 'big', 'medium') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as big_run_pct,
    ROUND(
      100.0 * SUM(CASE WHEN state IN ('R', 'R+') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as runnable_pct,
    ROUND(
      100.0 * SUM(CASE WHEN state IN ('S', 'D', 'I', 'DK') AND overlap_ns > 0 THEN overlap_ns ELSE 0 END)
      / NULLIF((SELECT slice_dur_ns FROM top_slice_bounds), 0),
      1
    ) as blocked_pct
  FROM top_slice_state_overlap
),
system_windows AS (
  SELECT 'frame' AS window_id,${start_ts} AS window_start_ts,${end_ts} AS window_end_ts
  UNION ALL SELECT 'top_slice',MAX(slice_start_ns,${start_ts}),MIN(slice_end_ns,${end_ts}) FROM top_slice_bounds
),
-- 5. 频率上限约束（fragments/system_cpu_freq_limit_frame_binding.sql，与
-- scrolling_analysis batch_frame_root_cause 同一判定）。MainThread 的归属区间是
-- 裁剪到帧窗口的 top slice，且只计执行它的那个线程（*.ui 等其他 MainThread 角色
-- 线程不计）；RenderThread 为整帧，只作诊断。没有 top slice 或裁剪后为空区间时
-- MainThread 行不存在，freq_limit_state 为 NULL，不产生限频 reason。
system_work_intervals AS (
  SELECT 'frame' AS window_id,'MainThread' AS role,slice_utid AS utid,
    MAX(slice_start_ns,${start_ts}) AS work_start_ts,MIN(slice_end_ns,${end_ts}) AS work_end_ts
  FROM top_slice_bounds
  UNION ALL SELECT 'frame','RenderThread',NULL,${start_ts},${end_ts}
),
frame_freq_limit_main AS (
  SELECT * FROM system_cpu_freq_limit_frame_binding WHERE window_id='frame' AND role='MainThread'
),
frame_freq_limit_render AS (
  SELECT * FROM system_cpu_freq_limit_frame_binding WHERE window_id='frame' AND role='RenderThread'
),
freq_info AS (
  SELECT
    ROUND((SUM(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.freq_khz*1.0*f.dur_ns END)/NULLIF(SUM(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.dur_ns END),0))/1000,0) AS big_avg_freq,
    ROUND((MAX(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.freq_khz END))/1000,0) AS big_max_freq,
    ROUND((MIN(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.freq_khz END))/1000,0) AS big_min_freq,
    ROUND((SUM(CASE WHEN ct.core_type IN ('little') THEN f.freq_khz*1.0*f.dur_ns END)/NULLIF(SUM(CASE WHEN ct.core_type IN ('little') THEN f.dur_ns END),0))/1000,0) AS little_avg_freq,
    ROUND((MAX(CASE WHEN ct.core_type IN ('little') THEN f.freq_khz END))/1000,0) AS little_max_freq,
    ROUND((MIN(CASE WHEN ct.core_type IN ('little') THEN f.freq_khz END))/1000,0) AS little_min_freq
  FROM system_cpu_frequency_spans f LEFT JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu WHERE f.window_id='frame'
),
top_slice_freq AS (
  SELECT
    ROUND((SUM(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.freq_khz*1.0*f.dur_ns END)/NULLIF(SUM(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.dur_ns END),0))/1000,0) AS top_big_avg_freq_mhz,
    ROUND((MAX(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.freq_khz END))/1000,0) AS top_big_max_freq_mhz,
    ROUND((MIN(CASE WHEN ct.core_type IN ('prime','big','medium') THEN f.freq_khz END))/1000,0) AS top_big_min_freq_mhz,
    ROUND((SUM(CASE WHEN ct.core_type IN ('little') THEN f.freq_khz*1.0*f.dur_ns END)/NULLIF(SUM(CASE WHEN ct.core_type IN ('little') THEN f.dur_ns END),0))/1000,0) AS top_little_avg_freq_mhz
  FROM system_cpu_frequency_spans f LEFT JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu WHERE f.window_id='top_slice'
),
big_freq_window AS (
  SELECT f.clipped_start_ts AS ts,f.freq_khz,f.dur_ns
  FROM system_cpu_frequency_spans f JOIN system_cpu_topology ct ON ct.ucpu=f.ucpu
  WHERE f.window_id='frame' AND ct.core_type IN ('prime','big','medium')
),
big_freq_stats AS (
  SELECT
    MAX(freq_khz) as peak_khz,
    MIN(freq_khz) as min_khz,
    SUM(freq_khz*1.0*dur_ns)/NULLIF(SUM(dur_ns),0) as avg_khz
  FROM big_freq_window
),
big_freq_ramp AS (
  SELECT
    ROUND(
      (
        COALESCE(
          MIN(
            CASE
              WHEN b.freq_khz >=
                CASE
                  WHEN s.peak_khz IS NULL THEN NULL
                  WHEN s.peak_khz * 0.70 > 1800000 THEN s.peak_khz * 0.70
                  ELSE 1800000
                END
              THEN b.ts
            END
          ),
          ${end_ts}
        ) - ${start_ts}
      ) / 1e6,
      2
    ) as ramp_to_high_ms,
    ROUND(
      (COALESCE(MIN(CASE WHEN b.freq_khz >= 2000000 THEN b.ts END), ${end_ts}) - ${start_ts}) / 1e6,
      2
    ) as ramp_to_2g_ms
  FROM big_freq_window b
  CROSS JOIN big_freq_stats s
),
system_target_threads AS (
  SELECT 'frame' AS window_id,t.upid,tt.utid,tt.thread_type AS role
  FROM target_threads tt JOIN thread t ON t.utid=tt.utid
),
-- 6. IO/page-cache 候选检测（主线程 D/DK + io_wait/blocked_function）
io_block AS (
  SELECT COALESCE(ROUND(SUM(ts2.dur_ns) / 1e6, 2), 0) as io_block_ms
  FROM system_thread_state_spans ts2
  JOIN target_threads tt2 ON ts2.utid = tt2.utid
  WHERE tt2.thread_type = 'MainThread'
    AND ts2.window_id = 'frame'
    AND ts2.state IN ('D', 'DK')
    AND (
      COALESCE(ts2.io_wait, 0) = 1
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%filemap%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%page_fault%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%wait_on_page%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%folio_wait%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%io_schedule%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%submit_bio%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%sync%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%blk_%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%ext4%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%f2fs%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%erofs%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%ufshcd%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%mmc_%'
      OR LOWER(COALESCE(ts2.blocked_function, '')) LIKE '%dm_%'
    )
),
-- 7. 调度延迟检测（Runnable 等待）
sched_latency AS (
  SELECT
    COALESCE(ROUND(MAX(ts3.dur_ns) / 1e6, 2), 0) as max_sched_ms,
    COALESCE(ROUND(SUM(ts3.dur_ns) / 1e6, 2), 0) as total_sched_ms
  FROM system_thread_state_spans ts3
  JOIN target_threads tt3 ON ts3.utid = tt3.utid
  WHERE tt3.thread_type = 'MainThread'
    AND ts3.window_id = 'frame'
    AND ts3.state IN ('R', 'R+')
),
-- 8. GPU Fence / GPU 同步检测
-- 包含 GPU fence 等待、eglSwapBuffers（GPU backpressure）、dequeueBuffer（BufferQueue 阻塞）
gpu_fence AS (
  SELECT COALESCE(ROUND(SUM(s.dur) / 1e6, 2), 0) as fence_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster')
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND (s.name GLOB '*Fence*' OR s.name GLOB '*fence*'
         OR s.name GLOB '*eglSwapBuffers*'
         OR s.name GLOB '*dequeueBuffer*')
),
-- 8b. Shader 编译检测（RenderThread 上的着色器编译/管线创建 slice）
shader_compile AS (
  SELECT
    COALESCE(ROUND(SUM(s.dur) / 1e6, 2), 0) as shader_ms,
    COUNT(*) as shader_count
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN effective_target_processes p ON t.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND (t.name = 'RenderThread' OR t.name GLOB '[0-9]*.raster')
    AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
    AND (s.name GLOB '*shader*' OR s.name GLOB '*Shader*'
         OR s.name GLOB '*Compile*' OR s.name GLOB '*compile*'
         OR s.name GLOB 'GrGLGpu*'
         OR s.name GLOB '*Pipeline*Create*'
         OR s.name GLOB '*programCache*')
),
-- 9. CPU 簇负载：与 cpu_cluster_load 步骤的簇表同一定义（fragments/cpu_cluster_load.sql），
-- 大核 = 超大核+大核+中核合计，小核 = 小核簇；拓扑无法分级时为 NULL。
-- 依赖 init_cpu_topology 物化的 _cpu_topology：它不存在时本步骤失败，
-- 而不是静默算出与簇表不同的负载
cluster_load AS (
  SELECT
    ROUND(100.0*SUM(CASE WHEN core_type IN ('prime','big','medium') THEN running_ns ELSE 0 END)
      /NULLIF(MAX(awake_ns)*SUM(CASE WHEN core_type IN ('prime','big','medium') THEN core_count ELSE 0 END),0),1) AS big_load_pct,
    ROUND(100.0*SUM(CASE WHEN core_type='little' THEN running_ns ELSE 0 END)
      /NULLIF(MAX(awake_ns)*SUM(CASE WHEN core_type='little' THEN core_count ELSE 0 END),0),1) AS little_load_pct
  FROM cpu_cluster_load_by_tier
),
-- 10. GC 事件与帧窗口重叠检测
-- android_garbage_collection_events view 由 prerequisites 中的
-- INCLUDE PERFETTO MODULE android.garbage_collection 保证存在（可能为空）
gc_frame_overlap AS (
  SELECT
    COALESCE(ROUND(SUM(
      CASE WHEN MIN(gc.gc_ts + gc.gc_dur, ${end_ts}) > MAX(gc.gc_ts, ${start_ts})
        THEN MIN(gc.gc_ts + gc.gc_dur, ${end_ts}) - MAX(gc.gc_ts, ${start_ts})
        ELSE 0 END
    ) / 1e6, 2), 0) as gc_overlap_ms,
    COUNT(*) as gc_count
  FROM android_garbage_collection_events gc
  JOIN effective_target_processes p ON gc.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR '${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND gc.gc_ts < ${end_ts}
    AND gc.gc_ts + gc.gc_dur > ${start_ts}
),
-- 11. 主线程同步 Binder 与关键 slice 重叠分析
binder_sync_main AS (
  SELECT
    bt.client_ts,
    bt.client_dur,
    bt.server_process
  FROM android_binder_txns bt
  WHERE bt.client_utid IN (SELECT utid FROM main_thread_utid)
    AND bt.is_sync = 1
    AND bt.client_ts < ${end_ts}
    AND bt.client_ts + bt.client_dur > ${start_ts}
),
binder_frame AS (
  SELECT
    ROUND(COALESCE(SUM(client_dur), 0) / 1e6, 2) as sync_total_ms,
    ROUND(COALESCE(MAX(client_dur), 0) / 1e6, 2) as sync_max_ms,
    COUNT(*) as sync_count
  FROM binder_sync_main
),
binder_overlap AS (
  SELECT
    ROUND(
      COALESCE(
        SUM(
          CASE
            WHEN b.client_ts < tsb.slice_end_ns
              AND b.client_ts + b.client_dur > tsb.slice_start_ns
            THEN
              (
                CASE
                  WHEN b.client_ts + b.client_dur < tsb.slice_end_ns THEN b.client_ts + b.client_dur
                  ELSE tsb.slice_end_ns
                END
                -
                CASE
                  WHEN b.client_ts > tsb.slice_start_ns THEN b.client_ts
                  ELSE tsb.slice_start_ns
                END
              )
            ELSE 0
          END
        ),
        0
      ) / 1e6,
      2
    ) as overlap_ms,
    ROUND(
      COALESCE(
        MAX(
          CASE
            WHEN b.client_ts < tsb.slice_end_ns
              AND b.client_ts + b.client_dur > tsb.slice_start_ns
            THEN
              (
                CASE
                  WHEN b.client_ts + b.client_dur < tsb.slice_end_ns THEN b.client_ts + b.client_dur
                  ELSE tsb.slice_end_ns
                END
                -
                CASE
                  WHEN b.client_ts > tsb.slice_start_ns THEN b.client_ts
                  ELSE tsb.slice_start_ns
                END
              )
            ELSE 0
          END
        ),
        0
      ) / 1e6,
      2
    ) as max_overlap_ms,
    COALESCE(
      MAX(
        CASE
          WHEN b.client_ts < tsb.slice_end_ns
            AND b.client_ts + b.client_dur > tsb.slice_start_ns
          THEN b.server_process
          ELSE NULL
        END
      ),
      ''
    ) as overlap_server
  FROM binder_sync_main b
  JOIN top_slice_bounds tsb
),
-- 12. 综合根因判断
analysis AS (
  SELECT
    (SELECT dur_ms FROM top_slice) as slice_dur,
    (SELECT name FROM top_slice) as slice_name,
    ROUND(((SELECT slice_ts FROM top_slice) - ${start_ts}) / 1e6, 2) as top_slice_offset_ms,
    (SELECT q1 FROM main_summary) as main_q1,
    (SELECT q2 FROM main_summary) as main_q2,
    (SELECT q3 FROM main_summary) as main_q3,
    (SELECT q4a FROM main_summary) as main_q4a,
    (SELECT q4b FROM main_summary) as main_q4b,
    (SELECT q1 FROM render_summary) as render_q1,
    (SELECT q2 FROM render_summary) as render_q2,
    (SELECT q3 FROM render_summary) as render_q3,
    (SELECT q4a FROM render_summary) as render_q4a,
    (SELECT q4b FROM render_summary) as render_q4b,
    (SELECT big_avg_freq FROM freq_info) as big_freq,
    (SELECT big_max_freq FROM freq_info) as big_freq_peak,
    (SELECT big_min_freq FROM freq_info) as big_freq_min,
    (SELECT little_avg_freq FROM freq_info) as little_freq,
    (SELECT little_max_freq FROM freq_info) as little_freq_peak,
    (SELECT little_min_freq FROM freq_info) as little_freq_min,
    (SELECT little_run_pct FROM top_slice_cpu_mix) as top_slice_little_pct,
    (SELECT big_run_pct FROM top_slice_cpu_mix) as top_slice_big_pct,
    (SELECT runnable_pct FROM top_slice_cpu_mix) as top_slice_runnable_pct,
    (SELECT blocked_pct FROM top_slice_cpu_mix) as top_slice_blocked_pct,
    (SELECT top_big_avg_freq_mhz FROM top_slice_freq) as top_big_avg_freq_mhz,
    (SELECT top_big_max_freq_mhz FROM top_slice_freq) as top_big_max_freq_mhz,
    (SELECT top_big_min_freq_mhz FROM top_slice_freq) as top_big_min_freq_mhz,
    (SELECT top_little_avg_freq_mhz FROM top_slice_freq) as top_little_avg_freq_mhz,
    (SELECT ramp_to_high_ms FROM big_freq_ramp) as ramp_to_high_ms,
    (SELECT ramp_to_2g_ms FROM big_freq_ramp) as ramp_to_2g_ms,
    (SELECT overlap_ms FROM binder_overlap) as binder_overlap_ms,
    (SELECT max_overlap_ms FROM binder_overlap) as binder_max_overlap_ms,
    (SELECT overlap_server FROM binder_overlap) as binder_overlap_server,
    (SELECT sync_total_ms FROM binder_frame) as binder_sync_total_ms,
    (SELECT sync_max_ms FROM binder_frame) as binder_sync_max_ms,
    (SELECT sync_count FROM binder_frame) as binder_sync_count,
    (SELECT lock_contention_ms FROM monitor_lock_overlap) as lock_contention_ms,
    (SELECT render_sync_wait_ms FROM render_sync_wait) as render_sync_wait_ms,
    (SELECT render_sync_rt_work_ms FROM render_sync_rt_work) as render_sync_rt_work_ms,
    (SELECT io_block_ms FROM io_block) as io_block_ms,
    (SELECT max_sched_ms FROM sched_latency) as max_sched_ms,
    (SELECT total_sched_ms FROM sched_latency) as total_sched_ms,
    (SELECT fence_ms FROM gpu_fence) as fence_ms,
    (SELECT shader_ms FROM shader_compile) as shader_ms,
    (SELECT shader_count FROM shader_compile) as shader_count,
    (SELECT gc_overlap_ms FROM gc_frame_overlap) as gc_overlap_ms,
    (SELECT gc_count FROM gc_frame_overlap) as gc_count,
    (SELECT big_load_pct FROM cluster_load) as big_load_pct,
    (SELECT little_load_pct FROM cluster_load) as little_load_pct,
    (SELECT freq_limit_state FROM frame_freq_limit_main) as freq_limit_state,
    (SELECT freq_limit_basis FROM frame_freq_limit_main) as freq_limit_basis,
    (SELECT freq_limit_onset_confirmed FROM frame_freq_limit_main) as freq_limit_onset_confirmed,
    (SELECT freq_limit_onset_ts FROM frame_freq_limit_main) as freq_limit_onset_ts,
    (SELECT freq_limit_cooling_basis FROM frame_freq_limit_main) as freq_limit_cooling_basis,
    (SELECT policy_cpu FROM frame_freq_limit_main) as freq_limit_policy_cpu,
    (SELECT ROUND(limit_khz / 1000.0, 1) FROM frame_freq_limit_main) as freq_limit_mhz,
    (SELECT depth_pct FROM frame_freq_limit_main) as freq_limit_depth_pct,
    (SELECT binding_ratio FROM frame_freq_limit_main) as freq_limit_binding_ratio,
    (SELECT onset_binding_ns FROM frame_freq_limit_main) as freq_limit_onset_binding_ns,
    (SELECT binding_ns FROM frame_freq_limit_main) as freq_limit_binding_ns,
    (SELECT run_ns FROM frame_freq_limit_main) as freq_limit_run_ns,
    (SELECT trace_episode_id FROM frame_freq_limit_main) as freq_limit_trace_episode_id,
    (SELECT freq_limit_state FROM frame_freq_limit_render) as rt_freq_limit_state,
    (SELECT binding_ns FROM frame_freq_limit_render) as rt_freq_limit_binding_ns,
    (SELECT policy_cpu FROM frame_freq_limit_render) as rt_freq_limit_policy_cpu,
    ROUND((${end_ts} - ${start_ts}) / 1e6, 2) as frame_duration_ms,
    ROUND((SELECT vsync_period_ns FROM vsync_config) / 1e6, 2) as frame_budget_ms,
    ROUND(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.50, 2) as slice_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.20, 2.0), 2) as slice_warning_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.18, 1.5), 2) as gpu_fence_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.06, 0.8), 2) as gpu_fence_warning_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.30, 3.5), 2) as sched_max_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.18, 2.0), 2) as total_sched_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.12, 1.5), 2) as io_block_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.18, 1.5), 2) as binder_overlap_critical_ms,
    ROUND(MAX(((SELECT vsync_period_ns FROM vsync_config) / 1e6) * 0.35, 2.0), 2) as freq_ramp_critical_ms
)
, classified AS (
  SELECT
    *,
    CASE
      -- P0: Buffer Stuffing 管线背压 — 短路跳过线程分析
      WHEN '${jank_responsibility}' = 'BUFFER_STUFFING'
        THEN 'buffer_stuffing'
      -- P1: Binder 同步阻塞（特定可操作，阻塞可能占据 slice 大部分时间）
      WHEN slice_dur > slice_critical_ms
        AND binder_overlap_ms >= binder_overlap_critical_ms
        THEN 'binder_sync_blocking'
      -- P1.25: 主线程 monitor contention 与当前帧有直接重叠。
      WHEN lock_contention_ms > 0.2
        THEN 'lock_contention'
      -- P2: 小核调度（可能导致 3-4x 性能损失，可操作）
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(top_slice_little_pct, 0) >= 45
        THEN 'small_core_placement'
      -- P3: 关键操作中的调度延迟
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(top_slice_runnable_pct, 0) >= 15
        THEN 'sched_delay_in_slice'
      -- P3.5: RenderThread 主动运行占比高，且不是等待型 RT 卡顿。
      WHEN (render_q1 + render_q2) > 70 AND render_q4b < 20
        THEN 'render_thread_heavy'
      -- P4: 重度业务负载（>2x 帧预算）— 即使在满频下也会超时
      -- 频率/调度等供给侧因素只是放大因素，不是根因
      WHEN slice_dur > frame_budget_ms * 2.0
        THEN 'workload_heavy'
      -- P4.5: 温控限频 — 主线程 top slice 的运行时间受 policy 频率上限约束
      -- （freq_limit_state = capped_binding），且约束它的那个上限值由与该 policy
      -- 时序关联的散热设备升档写入（onset verdict confirmed，且不是多个上限值拼出
      -- 的约束）。判据与 scrolling_analysis batch_frame_root_cause P4.5/P4.6 相同；
      -- SF 责任帧不命名 App 侧限频根因（batch 先按 SF 分流，cause_type 同一短路）。
      WHEN '${jank_responsibility}' <> 'SF'
        AND slice_dur > slice_critical_ms AND freq_limit_state = 'capped_binding'
        AND freq_limit_onset_confirmed = 1 AND freq_limit_basis <> 'mixed_limit_values_in_frame'
        THEN 'thermal_throttling'
      -- P4.6: CPU 最大频率被限 — 上限约束了主线程，但触发方未由帧内证据确定。
      WHEN '${jank_responsibility}' <> 'SF'
        AND slice_dur > slice_critical_ms AND freq_limit_state = 'capped_binding'
        THEN 'cpu_max_limited'
      -- P5: 大核低频（仅适用于边际情况：slice 在 1x-2x 帧预算区间）
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(top_slice_big_pct, 0) >= 40
        AND COALESCE(top_big_avg_freq_mhz, 0) > 0
        AND COALESCE(top_big_max_freq_mhz, 0) > 0
        AND top_big_avg_freq_mhz < top_big_max_freq_mhz * 0.55
        THEN 'big_core_low_freq'
      -- P6: 频率爬升慢（仅适用于边际情况：slice 在 1x-2x 帧预算区间）
      WHEN slice_dur > slice_critical_ms
        AND COALESCE(ramp_to_high_ms, 0) > freq_ramp_critical_ms
        AND COALESCE(top_slice_offset_ms, 0) <= ramp_to_high_ms
        THEN 'freq_ramp_slow'
      -- P7: 工作负载超时兜底（1x-2x 帧预算，无特定供给侧因素）
      WHEN slice_dur > slice_critical_ms
        THEN 'workload_heavy'
      -- P8: GC 导致帧卡顿（GC pause 与帧窗口重叠 > 1ms）
      WHEN gc_overlap_ms > 1.0
        THEN 'gc_jank'
      WHEN max_sched_ms > sched_max_critical_ms
        OR total_sched_ms > total_sched_critical_ms
        OR main_q3 > 20
        THEN 'scheduling_delay'
      WHEN main_q2 > 50
        THEN 'small_core_placement'
      -- Shader 编译（首次渲染特定图形效果时的编译开销）
      WHEN COALESCE(shader_ms, 0) > gpu_fence_warning_ms
        THEN 'shader_compile'
      -- GPU Fence 等待（渲染管线瓶颈，比 CPU 负载更具可操作性）
      WHEN fence_ms > gpu_fence_warning_ms
        THEN 'gpu_wait'
      WHEN big_freq > 0 AND big_freq_peak > 0 AND big_freq < big_freq_peak * 0.45
        THEN 'big_core_low_freq'
      WHEN big_load_pct > 90 OR (big_load_pct > 70 AND little_load_pct > 70)
        THEN 'cpu_load_high'
      WHEN io_block_ms > io_block_critical_ms
        THEN 'io_page_cache_wait'
      WHEN main_q4a > 20
        THEN 'uninterruptible_wait'
      WHEN main_q4b > 30
        AND render_sync_wait_ms >= MAX(frame_budget_ms * 0.20, frame_duration_ms * 0.25)
        AND (
          (render_q1 + render_q2) >= 30
          OR render_sync_rt_work_ms > 0
        )
        THEN 'render_sync_wait'
      ELSE 'unknown'
    END as reason_code
  FROM analysis
)
, base_result AS (
  SELECT
    CASE
      WHEN reason_code = 'render_thread_heavy' THEN
        'RenderThread 主动运行占比 ' || ROUND(render_q1 + render_q2, 1) ||
        '%，RT 工作主导；UI→RT 同步等待 ' || COALESCE(render_sync_wait_ms, 0) || 'ms 为依赖放大'
      WHEN reason_code = 'render_sync_wait' THEN
        '主线程发生 material UI→RenderThread 同步等待 ' || render_sync_wait_ms ||
        'ms（帧预算 ' || frame_budget_ms || 'ms，帧耗时 ' || frame_duration_ms || 'ms）'
      -- 限频根因的主因文案与 scrolling_analysis batch_frame_root_cause 相同
      WHEN reason_code = 'thermal_throttling' THEN
        '温控限频: "' || slice_name || '" 运行 ' || ROUND(freq_limit_run_ns / 1e6, 2) || 'ms 中有 ' ||
        ROUND(freq_limit_onset_binding_ns / 1e6, 2) || 'ms 受 policy' || freq_limit_policy_cpu || ' 上限 ' ||
        freq_limit_mhz || 'MHz 约束（低于观测最高上限 ' || freq_limit_depth_pct || '%，运行频率/上限 ' ||
        freq_limit_binding_ratio || '）；该上限值由与该 policy 时序关联的散热设备升档写入' ||
        CASE WHEN freq_limit_binding_ns > freq_limit_onset_binding_ns THEN '；跨全部上限值共受约束 ' || ROUND(freq_limit_binding_ns / 1e6, 2) || 'ms' ELSE '' END
      WHEN reason_code = 'cpu_max_limited' THEN
        'CPU限频生效: "' || slice_name || '" 运行 ' || ROUND(freq_limit_run_ns / 1e6, 2) || 'ms 中有 ' ||
        ROUND(freq_limit_onset_binding_ns / 1e6, 2) || 'ms 受 policy' || freq_limit_policy_cpu || ' 上限 ' ||
        freq_limit_mhz || 'MHz 约束（低于观测最高上限 ' || freq_limit_depth_pct || '%，运行频率/上限 ' ||
        freq_limit_binding_ratio || '）' ||
        CASE WHEN freq_limit_binding_ns > freq_limit_onset_binding_ns THEN '；跨全部上限值共受约束 ' || ROUND(freq_limit_binding_ns / 1e6, 2) || 'ms' ELSE '' END ||
        '；触发方未由帧内证据确定（' || COALESCE(freq_limit_basis, 'onset_unclassified') || '）'
      -- 优先级1: 主线程有明确耗时操作（相对帧预算）
      WHEN slice_dur > slice_critical_ms THEN
        '主线程耗时操作 "' || slice_name || '" 占用 ' || slice_dur || 'ms (帧预算 ' || frame_budget_ms || 'ms)'
      -- 优先级2: GPU Fence 等待（相对帧预算）
      WHEN fence_ms > gpu_fence_critical_ms THEN
        'GPU Fence 等待 ' || ROUND(fence_ms, 1) || 'ms，GPU 繁忙无法及时完成渲染'
      -- 优先级3: 严重调度延迟（相对帧预算）
      WHEN max_sched_ms > sched_max_critical_ms THEN
        '主线程调度延迟严重: 最大等待 ' || ROUND(max_sched_ms, 1) || 'ms'
      -- 优先级4: 主线程大量等待调度 (Q3 > 20%)
      WHEN main_q3 > 20 THEN
        '主线程 CPU 争抢严重 (' || main_q3 || '% 时间在等待调度)'
      -- 优先级5: 主线程 IO/page-cache 等待候选（相对帧预算）
      WHEN io_block_ms > io_block_critical_ms THEN
        '主线程 IO/page-cache 等待候选 ' || ROUND(io_block_ms, 1) || 'ms (D/DK + io_wait/blocked_function)'
      -- 优先级6: 总调度延迟（相对帧预算）
      WHEN total_sched_ms > total_sched_critical_ms THEN
        '主线程 Runnable 累计等待 ' || ROUND(total_sched_ms, 1) || 'ms'
      -- 优先级7a: 主线程不可中断等待 (Q4a > 20%)
      WHEN main_q4a > 20 THEN
        '主线程不可中断等待 (D/DK 状态)，占比 ' || main_q4a || '%；IO 归因需 io_wait/blocked_function'
      -- 优先级8: RenderThread 休眠 (Q4 > 50%)
      WHEN (render_q4a + render_q4b) > 50 THEN
        'RenderThread 长时间休眠 (' || (render_q4a + render_q4b) || '%)，等待主线程或 GPU'
      -- 优先级9: 主线程在小核运行 (Q2 > 50%)
      WHEN main_q2 > 50 THEN
        '主线程被调度到小核 (' || main_q2 || '%)，CPU 能力不足'
      -- 优先级10: 大核平均频率偏低。只是频率观测：低频可能来自负载、调速器或限频，
      -- 是否限频只由上方 freq_limit_* 的上限约束证据判定
      WHEN big_freq < 1200 AND big_freq > 0 THEN
        '大核平均频率仅 ' || big_freq || 'MHz（仅为频率观测；是否限频以本帧 CPU 限频证据为准）'
      -- 优先级11: 大核簇负载过高 (>90%)
      WHEN big_load_pct > 90 THEN
        '大核簇负载 ' || ROUND(big_load_pct, 0) || '%，CPU 资源严重不足'
      -- 优先级12: GPU Fence 中等延迟（相对帧预算）
      WHEN fence_ms > gpu_fence_warning_ms THEN
        'GPU Fence 等待 ' || ROUND(fence_ms, 1) || 'ms'
      -- 优先级13: CPU 整体负载高
      WHEN big_load_pct > 70 AND little_load_pct > 70 THEN
        'CPU 整体负载高 (大核 ' || ROUND(big_load_pct, 0) || '%, 小核 ' || ROUND(little_load_pct, 0) || '%)'
      -- 优先级14: 有中等耗时操作（相对帧预算）
      WHEN slice_dur > slice_warning_ms THEN
        '主线程操作 "' || slice_name || '" 耗时 ' || slice_dur || 'ms'
      -- 默认
      ELSE '帧耗时 ${dur_ms}ms 超过 VSync 周期(' || frame_budget_ms || 'ms)'
    END as primary_cause,
    CASE
      WHEN reason_code = 'buffer_stuffing' THEN
        'Buffer Stuffing: 管线背压，帧耗时 ' || ${dur_ms} || 'ms，BufferQueue 积压导致跳帧（非 App 问题）'
      WHEN reason_code = 'binder_sync_blocking' THEN
        'Binder 同步阻塞：关键操作与同步Binder重叠 ' || binder_overlap_ms || 'ms（累计 ' ||
        binder_sync_total_ms || 'ms' ||
        CASE
          WHEN COALESCE(binder_overlap_server, '') != '' THEN '，对端 ' || binder_overlap_server || ''
          ELSE ''
        END || '）'
      WHEN reason_code = 'lock_contention' THEN
        'Monitor 锁竞争：主线程在帧窗口内直接等待 ' || lock_contention_ms || 'ms'
      WHEN reason_code = 'render_sync_wait' THEN
        'UI→RenderThread 同步等待：postAndWait/syncFrameState 与帧重叠 ' || render_sync_wait_ms || 'ms'
      WHEN reason_code = 'render_thread_heavy' THEN
        'RenderThread 负载主导：主动运行占比 ' || ROUND(render_q1 + render_q2, 1) ||
        '%，UI→RT 同步等待 ' || COALESCE(render_sync_wait_ms, 0) || 'ms 是依赖放大而非锁/Binder'
      WHEN reason_code = 'small_core_placement' THEN
        '线程更多跑在小核：关键操作小核运行占比 ' || COALESCE(top_slice_little_pct, 0) ||
        '%（大核占比 ' || COALESCE(top_slice_big_pct, 0) || '%）'
      WHEN reason_code = 'sched_delay_in_slice' THEN
        '调度延迟：关键操作中 Runnable 等待占比 ' || COALESCE(top_slice_runnable_pct, 0) ||
        '%，主线程最大调度等待 ' || COALESCE(max_sched_ms, 0) || 'ms'
      WHEN reason_code = 'big_core_low_freq' THEN
        '大核低频：关键操作大核运行占比 ' || COALESCE(top_slice_big_pct, 0) ||
        '%，但平均频率仅 ' || COALESCE(top_big_avg_freq_mhz, big_freq) || 'MHz（片内峰值 ' ||
        COALESCE(top_big_max_freq_mhz, big_freq_peak) || 'MHz）'
      WHEN reason_code = 'thermal_throttling' THEN
        '温控限频：关键操作所在 policy' || freq_limit_policy_cpu || ' 的上限 ' || freq_limit_mhz ||
        'MHz 约束了主线程运行，该上限值的写入与温控散热设备升档配对确认'
      WHEN reason_code = 'cpu_max_limited' THEN
        'CPU 限频：关键操作所在 policy' || freq_limit_policy_cpu || ' 的上限 ' || freq_limit_mhz ||
        'MHz 约束了主线程运行；触发方（温控或功耗/厂商策略）未由帧内证据确定'
      WHEN reason_code = 'freq_ramp_slow' THEN
        '频率爬升慢：帧开始后 ' || COALESCE(ramp_to_high_ms, 0) ||
        'ms 才升到高频，关键操作起点 +' || COALESCE(top_slice_offset_ms, 0) || 'ms'
      WHEN reason_code = 'workload_heavy' THEN
        CASE
          WHEN slice_name GLOB '*RV*Prefetch*' OR slice_name GLOB '*OnBind*' OR slice_name GLOB '*Adapter*bind*' OR slice_name GLOB '*bind*'
            THEN '业务负载重：列表预取/绑定逻辑在主线程串行执行 ' || slice_dur || 'ms（超帧预算 ' || ROUND(slice_dur / NULLIF(frame_budget_ms, 0), 1) || '倍）'
          WHEN COALESCE(ramp_to_high_ms, 0) > freq_ramp_critical_ms
            THEN '业务负载重：操作耗时 ' || slice_dur || 'ms（超帧预算 ' || ROUND(slice_dur / NULLIF(frame_budget_ms, 0), 1) || '倍），频率爬升 ' || ramp_to_high_ms || 'ms 为次要加剧因素'
          ELSE '业务负载重：主线程操作耗时 ' || slice_dur || 'ms（超帧预算 ' || ROUND(slice_dur / NULLIF(frame_budget_ms, 0), 1) || '倍）'
        END
      WHEN reason_code = 'scheduling_delay' THEN
        '调度延迟：主线程 Runnable 累计 ' || COALESCE(total_sched_ms, 0) ||
        'ms（最大 ' || COALESCE(max_sched_ms, 0) || 'ms）'
      WHEN reason_code = 'cpu_load_high' THEN
        'CPU 负载高：大核负载 ' || COALESCE(big_load_pct, 0) ||
        '%，小核负载 ' || COALESCE(little_load_pct, 0) || '%'
      WHEN reason_code = 'io_page_cache_wait' THEN
        'IO/page-cache 等待候选：主线程 D/DK 且有 io_wait/blocked_function ' || COALESCE(io_block_ms, 0) || 'ms，Q4a 占比 ' || COALESCE(main_q4a, 0) || '%'
      WHEN reason_code = 'uninterruptible_wait' THEN
        '不可中断等待：主线程 Q4a(D/DK) 占比 ' || COALESCE(main_q4a, 0) || '%；IO 归因需 io_wait/blocked_function'
      WHEN reason_code = 'shader_compile' THEN
        'Shader 编译：RenderThread 上着色器编译耗时 ' || COALESCE(shader_ms, 0) || 'ms（' || COALESCE(shader_count, 0) || ' 次），首次渲染或新视觉效果触发'
      WHEN reason_code = 'gpu_wait' THEN
        'GPU 等待：RenderThread/GPU Fence 累计等待 ' || COALESCE(fence_ms, 0) || 'ms'
      WHEN reason_code = 'gc_jank' THEN
        'GC 暂停：帧窗口内 GC 重叠 ' || COALESCE(gc_overlap_ms, 0) || 'ms（' || COALESCE(gc_count, 0) || ' 次 GC）'
      ELSE NULL
    END as deep_reason,
    CASE
      WHEN reason_code = 'buffer_stuffing' THEN '非 App 问题：BufferQueue 管线背压导致跳帧。检查帧率设置是否匹配显示刷新率，或优化渲染管线吞吐'
      WHEN reason_code = 'binder_sync_blocking' THEN '优化方向：减少主线程同步 Binder（异步化/批量化/结果缓存）并压缩关键路径 IPC'
      WHEN reason_code = 'lock_contention' THEN '优化方向：缩短主线程 monitor 临界区，移出帧内共享锁并减少锁持有者工作量'
      WHEN reason_code = 'render_sync_wait' THEN '优化方向：减少 doFrame/DisplayList 工作量与 RenderThread 回放压力，缩短 postAndWait 同步边界'
      WHEN reason_code = 'render_thread_heavy' THEN '优化方向：定位并削减 RenderThread 的 DrawFrame、flush commands、Vulkan/Skia 回放与提交工作量'
      WHEN reason_code = 'small_core_placement' THEN '优化方向：保证关键滚动路径优先使用大核，减少后台线程对主线程的抢占'
      WHEN reason_code = 'sched_delay_in_slice' OR reason_code = 'scheduling_delay' THEN '优化方向：降低同窗并发与高优线程竞争，缩短主线程 Runnable 等待'
      WHEN reason_code = 'big_core_low_freq' THEN '优化方向：在输入/滚动前预拉频，避免大核低频执行关键 UI 热路径'
      WHEN reason_code = 'thermal_throttling' THEN '优化方向：降低持续负载与发热（削减关键路径计算量、避免后台高负载并发），并结合温控策略评估限频阈值'
      WHEN reason_code = 'cpu_max_limited' THEN '优化方向：先用 cpu_frequency_limit_attribution 确认限频触发方（温控或功耗/厂商策略），再决定降负载还是调整策略'
      WHEN reason_code = 'freq_ramp_slow' THEN '优化方向：使用 touch/scroll boost 提前拉频，减少频率爬升滞后'
      WHEN reason_code = 'workload_heavy' THEN
        CASE
          WHEN slice_name GLOB '*RV*Prefetch*' OR slice_name GLOB '*OnBind*' OR slice_name GLOB '*Adapter*bind*' OR slice_name GLOB '*bind*'
            THEN '优化方向：拆分 RV Prefetch/OnBind 重逻辑，预计算和缓存绑定数据，避免主线程串行重活'
          ELSE '优化方向：把关键帧内重逻辑拆分到后台并做结果复用，缩短主线程单次执行时长'
        END
      WHEN reason_code = 'cpu_load_high' THEN '优化方向：降低 CPU 总负载并限制后台并发，优先保障 UI 与 RenderThread 预算'
      WHEN reason_code = 'io_page_cache_wait' THEN '优化方向：补齐文件/数据库/Provider 证据；确认后将同步 IO 移至后台线程或使用异步 IO'
      WHEN reason_code = 'uninterruptible_wait' THEN '优化方向：先查 io_wait、blocked_function、page fault 和文件/数据库 slice，确认是否为 IO 后再定向优化'
      WHEN reason_code = 'shader_compile' THEN '优化方向：使用 PrecompiledShaders / Shader Warm-up 在启动时预编译着色器，避免滑动时动态编译'
      WHEN reason_code = 'gpu_wait' THEN '优化方向：降低 draw 复杂度/overdraw，减少 GPU Fence 等待'
      WHEN reason_code = 'gc_jank' THEN '优化方向：减少帧渲染路径上的对象分配，使用对象池化/预分配，避免 GC 暂停重叠关键帧'
      ELSE '优化方向：扩大同窗样本做聚类，确认该慢原因是否稳定复现'
    END as optimization_hint,
    reason_code,
    CASE
      WHEN reason_code = 'buffer_stuffing' THEN 'Buffer Stuffing 管线背压（jank_type=${jank_type}）'
      WHEN reason_code = 'binder_sync_blocking' THEN '同步 Binder 重叠 ' || COALESCE(binder_overlap_ms, 0) || 'ms'
      WHEN reason_code = 'lock_contention' THEN 'Monitor 锁竞争重叠 ' || COALESCE(lock_contention_ms, 0) || 'ms'
      WHEN reason_code = 'render_sync_wait' THEN 'UI→RenderThread 同步等待 ' || COALESCE(render_sync_wait_ms, 0) || 'ms'
      WHEN reason_code = 'render_thread_heavy' THEN 'RenderThread 主动运行 ' || ROUND(COALESCE(render_q1, 0) + COALESCE(render_q2, 0), 1) || '%，同步等待 ' || COALESCE(render_sync_wait_ms, 0) || 'ms'
      WHEN reason_code = 'small_core_placement' THEN '关键操作小核占比 ' || COALESCE(top_slice_little_pct, 0) || '%'
      WHEN reason_code = 'sched_delay_in_slice' THEN '关键操作 Runnable 占比 ' || COALESCE(top_slice_runnable_pct, 0) || '%'
      WHEN reason_code = 'big_core_low_freq' THEN '关键操作大核频率 ' || COALESCE(top_big_avg_freq_mhz, big_freq) || 'MHz'
      WHEN reason_code IN ('thermal_throttling', 'cpu_max_limited') THEN 'policy' || freq_limit_policy_cpu || ' 上限 ' || freq_limit_mhz || 'MHz 约束 ' || ROUND(freq_limit_onset_binding_ns / 1e6, 2) || 'ms（' || COALESCE(freq_limit_basis, 'onset_unclassified') || '）'
      WHEN reason_code = 'freq_ramp_slow' THEN '高频拉升耗时 ' || COALESCE(ramp_to_high_ms, 0) || 'ms'
      WHEN reason_code = 'workload_heavy' THEN '操作 "' || COALESCE(slice_name, 'unknown') || '" 耗时 ' || COALESCE(slice_dur, 0) || 'ms（超帧预算 ' || ROUND(COALESCE(slice_dur, 0) / NULLIF(frame_budget_ms, 0), 1) || 'x）' ||
        CASE WHEN COALESCE(ramp_to_high_ms, 0) > freq_ramp_critical_ms THEN '，频率爬升 ' || ramp_to_high_ms || 'ms 加剧' ELSE '' END
      WHEN reason_code = 'gc_jank' THEN 'GC 重叠 ' || COALESCE(gc_overlap_ms, 0) || 'ms（' || COALESCE(gc_count, 0) || ' 次）'
      WHEN reason_code = 'shader_compile' THEN 'Shader 编译 ' || COALESCE(shader_ms, 0) || 'ms（' || COALESCE(shader_count, 0) || ' 次）'
      WHEN fence_ms > gpu_fence_warning_ms THEN 'GPU Fence 等待 ' || ROUND(fence_ms, 1) || 'ms'
      WHEN total_sched_ms > (total_sched_critical_ms * 0.5) THEN '调度等待累计 ' || ROUND(total_sched_ms, 1) || 'ms'
      WHEN big_load_pct > 70 THEN '大核负载 ' || ROUND(big_load_pct, 0) || '%'
      WHEN big_freq > 0 AND big_freq < 1500 THEN '大核平均频率 ' || big_freq || 'MHz'
      WHEN main_q2 > 30 THEN '小核运行占比 ' || main_q2 || '%'
      ELSE NULL
    END as secondary_info,
    CASE
      WHEN reason_code = 'lock_contention' THEN '高'
      WHEN reason_code IN ('render_sync_wait', 'render_thread_heavy') THEN '中'
      WHEN reason_code = 'thermal_throttling' THEN '高'
      WHEN reason_code = 'cpu_max_limited' THEN '中'
      WHEN slice_dur > slice_critical_ms THEN '高'
      WHEN gc_overlap_ms > 1.0 THEN '高'
      WHEN fence_ms > gpu_fence_critical_ms THEN '高'
      WHEN max_sched_ms > sched_max_critical_ms THEN '高'
      WHEN main_q3 > 20 THEN '高'
      WHEN io_block_ms > io_block_critical_ms THEN '高'
      WHEN total_sched_ms > total_sched_critical_ms THEN '高'
      WHEN big_load_pct > 90 THEN '高'
      WHEN COALESCE(shader_ms, 0) > gpu_fence_warning_ms THEN '高'
      WHEN main_q4a > 20 THEN '中'
      WHEN fence_ms > gpu_fence_warning_ms THEN '中'
      WHEN big_load_pct > 70 AND little_load_pct > 70 THEN '中'
      WHEN slice_dur > slice_warning_ms THEN '中'
      ELSE '低'
    END as confidence,
    CASE
      -- SF 合成超时短路：jank_responsibility 指向 SF，App 侧指标不相关
      WHEN '${jank_responsibility}' = 'SF' THEN 'sf_composition'
      -- 只有上限约束证据（P4.5/P4.6）才是 freq_limit，且先于按 slice 判断
      WHEN reason_code IN ('thermal_throttling', 'cpu_max_limited') THEN 'freq_limit'
      WHEN reason_code = 'render_thread_heavy' THEN 'render_heavy'
      WHEN reason_code = 'render_sync_wait' THEN 'render_wait'
      WHEN reason_code = 'lock_contention' THEN 'blocking'
      WHEN slice_dur > slice_critical_ms THEN 'slice'
      WHEN fence_ms > gpu_fence_critical_ms THEN 'gpu_fence'
      WHEN max_sched_ms > sched_max_critical_ms THEN 'sched_latency'
      WHEN main_q3 > 20 THEN 'cpu_contention'
      WHEN io_block_ms > io_block_critical_ms THEN 'io_blocking'
      WHEN total_sched_ms > total_sched_critical_ms THEN 'sched_latency'
      WHEN main_q4a > 20 THEN 'io_blocking'
      -- RenderThread 负载过重：RT 主动运行，非等待 GPU/SF
      WHEN render_q4a < 10 AND render_q4b < 20 AND COALESCE(shader_ms, 0) <= gpu_fence_warning_ms
        AND fence_ms <= gpu_fence_warning_ms
        THEN 'render_heavy'
      WHEN (render_q4a + render_q4b) > 50 THEN 'render_wait'
      WHEN COALESCE(shader_ms, 0) > gpu_fence_warning_ms THEN 'shader_compile'
      WHEN gc_overlap_ms > 1.0 THEN 'gc_pause'
      WHEN main_q2 > 50 THEN 'small_core'
      -- 大核平均频率偏低只是供给不足的观测（映射 frequency_insufficient），不是限频证据。
      -- 这条绝对阈值启发式与 big_core_low_freq 同类，保留供给侧含义
      WHEN big_freq < 1200 AND big_freq > 0 THEN 'low_freq'
      WHEN big_load_pct > 90 THEN 'cpu_overload'
      WHEN fence_ms > gpu_fence_warning_ms THEN 'gpu_fence'
      WHEN big_load_pct > 70 AND little_load_pct > 70 THEN 'cpu_overload'
      ELSE 'unknown'
    END as cause_type,
    slice_name,
    slice_dur,
    frame_budget_ms,
    frame_duration_ms as frame_dur_ms,
    '${jank_type}' as jank_type,
    '${jank_responsibility}' as jank_responsibility,
    max_sched_ms,
    total_sched_ms,
    main_q2,
    main_q3,
    main_q4a,
    main_q4b,
    big_freq,
    big_freq_peak,
    top_slice_little_pct,
    top_slice_big_pct,
    top_slice_runnable_pct,
    top_big_avg_freq_mhz,
    top_big_max_freq_mhz,
    ramp_to_high_ms,
    binder_overlap_ms,
    lock_contention_ms,
    render_sync_wait_ms,
    render_sync_rt_work_ms,
    binder_sync_total_ms,
    big_load_pct,
    little_load_pct,
    io_block_ms,
    render_q4a,
    render_q4b,
    fence_ms,
    shader_ms,
    shader_count,
    sched_max_critical_ms,
    total_sched_critical_ms,
    io_block_critical_ms,
    freq_limit_state,
    freq_limit_basis,
    freq_limit_onset_confirmed,
    freq_limit_onset_ts,
    freq_limit_cooling_basis,
    freq_limit_policy_cpu,
    freq_limit_mhz,
    freq_limit_depth_pct,
    freq_limit_binding_ratio,
    freq_limit_onset_binding_ns,
    freq_limit_binding_ns,
    freq_limit_run_ns,
    freq_limit_trace_episode_id,
    rt_freq_limit_state,
    rt_freq_limit_binding_ns,
    rt_freq_limit_policy_cpu
  FROM classified
)
SELECT
  primary_cause,
  deep_reason,
  optimization_hint,
  reason_code,
  secondary_info,
  confidence,
  cause_type,
  slice_name,
  slice_dur,
  frame_budget_ms,
  main_q3 as main_q3_pct,
  main_q4a as main_q4a_pct,
  main_q4b as main_q4b_pct,
  render_q4a as render_q4a_pct,
  render_q4b as render_q4b_pct,
  max_sched_ms as main_max_sched_ms,
  io_block_ms as main_io_block_ms,
  fence_ms as gpu_fence_ms,
  lock_contention_ms,
  render_sync_wait_ms,
  render_sync_rt_work_ms,
  frame_dur_ms,
  jank_type,
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
  -- RenderThread 整帧状态，只作诊断
  rt_freq_limit_state,
  rt_freq_limit_binding_ns,
  rt_freq_limit_policy_cpu,
  CASE
    WHEN cause_type IN ('slice', 'blocking', 'io_blocking') THEN 'trigger'
    WHEN cause_type IN ('sched_latency', 'cpu_contention', 'small_core', 'freq_limit', 'low_freq', 'cpu_overload') THEN 'supply'
    WHEN cause_type IN ('gpu_fence', 'render_wait', 'shader_compile') THEN 'amplification'
    WHEN cause_type = 'gc_pause' THEN 'trigger'
    WHEN cause_type = 'sf_composition' THEN 'amplification'
    WHEN cause_type = 'render_heavy' THEN 'trigger'
    ELSE 'unknown'
  END as mechanism_group,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'none'
    WHEN reason_code = 'sf_composition_slow' THEN 'none'
    WHEN reason_code = 'thermal_throttling' THEN 'thermal_throttle'
    WHEN reason_code IN ('binder_sync_blocking', 'lock_contention', 'io_page_cache_wait', 'uninterruptible_wait', 'lock_binder_wait', 'binder_timeout') THEN 'blocking_wait'
    WHEN reason_code = 'render_sync_wait' THEN 'none'
    WHEN reason_code = 'gc_jank' THEN 'gc_pause'
    WHEN reason_code = 'gc_pressure_cascade' THEN 'gc_pause'
    WHEN reason_code = 'small_core_placement' THEN 'core_placement'
    WHEN reason_code IN ('big_core_low_freq', 'freq_ramp_slow', 'cpu_max_limited') THEN 'frequency_insufficient'
    WHEN reason_code IN ('sched_delay_in_slice', 'scheduling_delay') THEN 'scheduling_delay'
    WHEN reason_code IN ('cpu_load_high', 'cpu_saturation') THEN 'load_high'
    WHEN reason_code = 'main_thread_file_io' THEN 'blocking_wait'
    WHEN reason_code = 'render_thread_heavy' THEN 'none'
    WHEN reason_code = 'shader_compile' THEN 'none'
    WHEN reason_code = 'workload_heavy' THEN 'none'
    WHEN io_block_ms > io_block_critical_ms OR main_q4a > 20 THEN 'blocking_wait'
    WHEN big_freq < 1200 AND big_freq > 0 THEN 'frequency_insufficient'
    WHEN main_q2 > 50 THEN 'core_placement'
    WHEN max_sched_ms > sched_max_critical_ms OR total_sched_ms > total_sched_critical_ms OR main_q3 > 20 THEN 'scheduling_delay'
    WHEN big_load_pct > 90 OR (big_load_pct > 70 AND little_load_pct > 70) THEN 'load_high'
    WHEN cause_type IN ('freq_limit', 'low_freq') THEN 'frequency_insufficient'
    WHEN cause_type = 'small_core' THEN 'core_placement'
    WHEN cause_type IN ('sched_latency', 'cpu_contention') THEN 'scheduling_delay'
    WHEN cause_type = 'cpu_overload' THEN 'load_high'
    WHEN cause_type IN ('blocking', 'io_blocking') THEN 'blocking_wait'
    ELSE 'none'
  END as supply_constraint,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'buffer_pipeline'
    WHEN reason_code = 'sf_composition_slow' THEN 'sf_consumer'
    WHEN cause_type IN ('slice', 'blocking', 'io_blocking', 'sched_latency', 'cpu_contention', 'small_core', 'freq_limit', 'low_freq', 'cpu_overload', 'gc_pause', 'render_heavy') THEN 'app_producer'
    WHEN cause_type IN ('gpu_fence', 'render_wait', 'shader_compile', 'sf_composition') THEN 'sf_consumer'
    ELSE 'unknown'
  END as trigger_layer,
  CASE
    WHEN reason_code = 'buffer_stuffing' THEN 'buffer_queue_backpressure'
    WHEN reason_code = 'sf_composition_slow' THEN 'sf_consumer_backpressure'
    WHEN cause_type = 'gpu_fence' THEN 'gpu_fence_wait'
    WHEN cause_type = 'shader_compile' THEN 'shader_compile_stall'
    WHEN cause_type IN ('render_wait', 'sf_composition') THEN 'render_pipeline_wait'
    WHEN cause_type = 'render_heavy' THEN 'app_deadline_miss'
    WHEN jank_responsibility = 'SF' THEN 'sf_consumer_backpressure'
    WHEN jank_responsibility = 'APP' THEN 'app_deadline_miss'
    ELSE 'unknown'
  END as amplification_path
FROM base_result
