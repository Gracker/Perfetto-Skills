-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: 0d32b714099786b1f04373b24b023fe8d99c6ce586baf33b2d38df56751b1044

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
  -- Frequency-limit facts come only from the shared verdict layer. Window 0
  -- is this analysis window: its classification is the only in-window
  -- statement. thermal_trending is whether the limit trigger in the window
  -- is a confirmed kernel cooling write (NULL when the trace has no valid max
  -- limit sample); thermal_evidence keeps the window classification under
  -- its historical name. freq_limit_trace_summary is trace-wide context and
  -- says nothing about a limit during this window.
  CASE WHEN fw.has_max_limit_data = 1 THEN fw.is_confirmed END AS thermal_trending,
  fw.freq_limit_classification AS thermal_evidence,
  fw.freq_limit_classification,
  fw.episode_count AS freq_limit_episode_count,
  fw.confirmed_episode_count AS freq_limit_confirmed_episode_count,
  fw.onset_trigger_mix AS freq_limit_onset_trigger_mix,
  fw.class_note AS freq_limit_class_note,
  fw.limit_evidence_missing_reason AS freq_limit_evidence_missing_reason,
  ft.freq_limit_classification AS freq_limit_trace_summary,
  ft.classification_scope AS freq_limit_trace_summary_scope,
  bg.non_app_big_core_pct as non_app_big_core_pct,
  CASE WHEN bg.non_app_big_core_pct > 60 THEN 1 WHEN bg.non_app_big_core_pct IS NULL THEN NULL ELSE 0 END as background_cpu_heavy
FROM video_check v, interpolation_check i, thermal_check th, background_cpu bg
CROSS JOIN system_cpu_freq_limit_window_summary fw
CROSS JOIN system_cpu_freq_limit_trace_summary ft
WHERE fw.window_id = 0
