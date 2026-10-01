-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_limit_timeline.skill.yaml
-- Source SHA-256: 352702371456ef9840b8601360663914d0190087759e74f94650be5ffdea8483

WITH
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
data_start AS (
  SELECT MIN(x) AS ts FROM (
    SELECT MIN(ts) AS x FROM sched_slice
    UNION ALL
    SELECT MIN(c.ts) FROM counter c JOIN cpu_counter_track t ON c.track_id = t.id
      WHERE t.type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')
  )
),
system_windows AS (
  SELECT 0 AS window_id,
    COALESCE(${start_ts}, (SELECT ts FROM data_start), (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
)
-- Validity, direction and episode membership come from the shared
-- event CTE; an invalid sample is a data-quality event, and the first
-- valid value after it has direction `unknown`, never `relaxed`.
SELECT s.raw_start_ts AS ts, s.policy_cpu, s.core_type, s.kind,
  ev.prev_sample_limit_khz AS prev_limit_khz, s.limit_khz, ev.delta_khz,
  ev.direction, ev.direction_basis, ev.limit_value_valid, ev.event_role,
  ev.trace_episode_id,
  s.dur_ns, s.reference_max_limit_khz, s.limit_source,
  'observation_not_causal' AS evidence_scope
FROM system_cpu_freq_limit_spans s
JOIN system_cpu_freq_limit_events ev ON ev.counter_id = s.counter_id
WHERE s.raw_start_ts >= s.window_start_ts AND s.raw_start_ts < s.window_end_ts
ORDER BY s.raw_start_ts, s.policy_cpu, s.kind DESC
