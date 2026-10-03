-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
-- Source SHA-256: 758e7664b2091d3e128ef1d06d88c4a311526ec85bac8f6db15d7dc1510901e3

WITH
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
SELECT
  ds.has_max_limit_data,
  ds.has_any_limit_sample,
  ds.limit_evidence_missing_reason,
  cov.cooling_transition_coverage AS has_cdev_data,
  cov.cooling_track_count,
  CASE WHEN EXISTS (SELECT 1 FROM counter_track WHERE type = 'thermal_temperature')
    THEN 1 ELSE 0 END AS has_temperature_data,
  CASE WHEN EXISTS (SELECT 1 FROM cpu_counter_track WHERE type = 'cpu_frequency')
    THEN 1 ELSE 0 END AS has_cpufreq_data,
  CASE WHEN EXISTS (SELECT 1 FROM sched_slice) THEN 1 ELSE 0 END AS has_sched_data
FROM system_cpu_freq_limit_data_status ds
CROSS JOIN thermal_cooling_transition_coverage cov
