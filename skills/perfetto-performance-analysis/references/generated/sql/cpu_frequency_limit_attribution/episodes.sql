-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
-- Source SHA-256: 9b27b3315b361c5cd21809d36d2415240a89ae8baf023b849ee3a4a8ba068888
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- The recorded data range a window may be clipped to. `trace_bounds` can
-- start well before the first scheduler sample (clock snapshots, early
-- metadata), so "data start" is the first sched_slice when one exists.
-- A lookback window that reaches before this point is reported as clipped,
-- never silently extended into unrecorded time.
observed_data_bounds AS (
  SELECT
    COALESCE((SELECT MIN(ts) FROM sched_slice), (SELECT start_ts FROM trace_bounds)) AS data_start_ts,
    (SELECT end_ts FROM trace_bounds) AS data_end_ts
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
-- Requires fragments/system_sched_spans.sql to be injected FIRST: policy
-- leader CPUs are classified through its system_cpu_topology, so every CPU
-- Skill shares one big/little definition.
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
system_cpu_freq_limit_raw AS (
  SELECT t.id AS track_id, t.cpu AS policy_cpu,
    CASE WHEN t.type='cpu_max_frequency_limit' THEN 'max' ELSE 'min' END AS kind,
    c.id AS counter_id, c.ts, CAST(c.value AS INTEGER) AS limit_khz,
    CAST(LAG(c.value) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS INTEGER) AS prev_limit_khz,
    LEAD(c.ts) OVER (PARTITION BY t.id ORDER BY c.ts, c.id) AS next_ts
  FROM cpu_counter_track t JOIN counter c ON c.track_id = t.id
  WHERE t.type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')
),
system_cpu_freq_limit_reference AS (
  SELECT policy_cpu,
    MAX(CASE WHEN kind='max' THEN limit_khz END) AS reference_max_limit_khz,
    MIN(CASE WHEN kind='max' THEN ts END) AS first_max_sample_ts,
    MAX(CASE WHEN kind='max' THEN ts END) AS last_max_sample_ts,
    'observed_max_limit_in_trace_not_hardware_max' AS reference_basis
  FROM system_cpu_freq_limit_raw
  GROUP BY policy_cpu
),
system_cpu_freq_limit_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    r.track_id, r.policy_cpu, r.kind, r.counter_id,
    r.limit_khz, r.prev_limit_khz,
    tp.ucpu, tp.machine_id, tp.capacity,
    COALESCE(tp.core_type, 'unknown') AS core_type,
    COALESCE(tp.topology_source, 'cpu_identity_unavailable') AS topology_source,
    r.ts AS raw_start_ts,
    COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)) AS raw_end_ts,
    MAX(r.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)), w.window_end_ts) AS clipped_end_ts,
    MIN(COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)), w.window_end_ts)
      - MAX(r.ts, w.window_start_ts) AS dur_ns,
    r.ts < w.window_start_ts AS left_censored,
    r.next_ts IS NULL OR r.next_ts > w.window_end_ts AS right_censored,
    r.ts = ref.first_max_sample_ts AND r.kind='max' AS is_first_max_sample,
    r.ts = ref.last_max_sample_ts AND r.kind='max' AS is_last_max_sample,
    ref.reference_max_limit_khz, ref.reference_basis,
    'ftrace:power/cpu_frequency_limits' AS limit_source
  FROM system_windows w
  JOIN system_cpu_freq_limit_raw r
    ON r.ts < w.window_end_ts
    AND COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)) > w.window_start_ts
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
-- A max-limit span counts as capped when it sits below the per-policy observed
-- reference by more than ${episode_drop_pct|10} percent. Consecutive capped
-- spans separated by a gap shorter than ${merge_gap_ms|500} ms become ONE
-- episode: kernel governors re-write the limit every few tens of milliseconds,
-- so the raw event stream would otherwise report hundreds of "episodes" for a
-- single continuous mitigation.
--
-- Both thresholds are inputs. They bound what is reported, not what happened.
-- `starts_at_data_start` marks an episode whose first capped span is the very
-- first observed sample of that track: the onset is outside the recorded data
-- and is unknown, not "the limit began here".
system_cpu_freq_limit_capped_spans AS (
  SELECT s.*
  FROM system_cpu_freq_limit_spans s
  WHERE s.kind = 'max'
    AND s.dur_ns > 0
    AND s.reference_max_limit_khz > 0
    AND s.limit_khz < s.reference_max_limit_khz * (1.0 - (${episode_drop_pct|10}) / 100.0)
),
system_cpu_freq_limit_capped_marked AS (
  SELECT s.*,
    LAG(s.clipped_end_ts) OVER (
      PARTITION BY s.window_id, s.policy_cpu
      ORDER BY s.clipped_start_ts, s.counter_id
    ) AS prev_capped_end_ts
  FROM system_cpu_freq_limit_capped_spans s
),
system_cpu_freq_limit_capped_grouped AS (
  SELECT m.*,
    SUM(CASE WHEN m.prev_capped_end_ts IS NULL
      OR m.clipped_start_ts - m.prev_capped_end_ts >= CAST((${merge_gap_ms|500}) * 1000000 AS INTEGER)
      THEN 1 ELSE 0 END) OVER (
      PARTITION BY m.window_id, m.policy_cpu
      ORDER BY m.clipped_start_ts, m.counter_id
      ROWS UNBOUNDED PRECEDING
    ) AS episode_seq
  FROM system_cpu_freq_limit_capped_marked m
),
system_cpu_freq_limit_episodes AS (
  SELECT
    g.window_id,
    g.policy_cpu,
    g.episode_seq,
    printf('policy%d-ep%d', g.policy_cpu, g.episode_seq) AS episode_id,
    MAX(g.ucpu) AS ucpu,
    MAX(g.machine_id) AS machine_id,
    MAX(g.capacity) AS capacity,
    MAX(g.core_type) AS core_type,
    MAX(g.topology_source) AS topology_source,
    MIN(g.clipped_start_ts) AS episode_start_ts,
    MAX(g.clipped_end_ts) AS episode_end_ts,
    MAX(g.clipped_end_ts) - MIN(g.clipped_start_ts) AS episode_dur_ns,
    MIN(g.limit_khz) AS min_limit_khz,
    MAX(g.limit_khz) AS max_limit_khz_in_episode,
    MAX(g.reference_max_limit_khz) AS reference_max_limit_khz,
    MAX(g.reference_basis) AS reference_basis,
    ROUND(100.0 * (MAX(g.reference_max_limit_khz) - MIN(g.limit_khz))
      / NULLIF(MAX(g.reference_max_limit_khz), 0), 1) AS depth_pct,
    COUNT(*) AS change_count,
    MAX(CASE WHEN g.is_first_max_sample THEN 1 ELSE 0 END) AS starts_at_data_start,
    MAX(CASE WHEN g.is_last_max_sample THEN 1 ELSE 0 END) AS ends_at_data_end,
    MAX(CASE WHEN g.left_censored THEN 1 ELSE 0 END) AS clipped_at_window_start,
    MAX(CASE WHEN g.right_censored THEN 1 ELSE 0 END) AS clipped_at_window_end,
    MAX(g.limit_source) AS limit_source,
    CASE WHEN MAX(CASE WHEN g.is_first_max_sample THEN 1 ELSE 0 END) = 1
        OR MAX(CASE WHEN g.is_last_max_sample THEN 1 ELSE 0 END) = 1
        OR MAX(CASE WHEN g.left_censored THEN 1 ELSE 0 END) = 1
        OR MAX(CASE WHEN g.right_censored THEN 1 ELSE 0 END) = 1
      THEN 'partial' ELSE 'observed' END AS evidence_status,
    'observation_not_causal' AS evidence_scope
  FROM system_cpu_freq_limit_capped_grouped g
  GROUP BY g.window_id, g.policy_cpu, g.episode_seq
)
,
system_windows AS (
  SELECT 0 AS window_id,
    ${analysis_window.data[0].window_start_ts} AS window_start_ts,
    ${analysis_window.data[0].window_end_ts} AS window_end_ts
)
SELECT e.episode_id, e.policy_cpu, e.core_type, e.topology_source,
  e.episode_start_ts, e.episode_end_ts, e.episode_dur_ns,
  e.min_limit_khz, e.reference_max_limit_khz, e.reference_basis,
  e.depth_pct, e.change_count,
  e.starts_at_data_start, e.ends_at_data_end, e.evidence_status,
  ROUND(e.depth_pct * (e.episode_dur_ns / 1e6) * COALESCE(e.capacity, 1), 1) AS impact_rank_score,
  MAX(db.data_start_ts, e.episode_start_ts - CAST(${lookback_ms|10000} * 1000000 AS INTEGER)) AS before_start_ts,
  e.episode_start_ts AS before_end_ts,
  CASE WHEN e.episode_start_ts - CAST(${lookback_ms|10000} * 1000000 AS INTEGER) < db.data_start_ts
    THEN 1 ELSE 0 END AS window_clipped_to_data_start,
  MAX(db.data_start_ts, e.episode_start_ts - CAST(${who_window_ms|2000} * 1000000 AS INTEGER)) AS who_start_ts,
  MIN(db.data_end_ts, e.episode_start_ts + CAST(${who_window_ms|2000} * 1000000 AS INTEGER)) AS who_end_ts,
  '${package}' AS package,
  '${process_name}' AS process_name,
  ${lookback_ms|10000} AS lookback_ms,
  ${who_window_ms|2000} AS who_window_ms,
  ${cooling_coincidence_ms|50} AS cooling_coincidence_ms,
  ${top_n|30} AS top_n,
  ${sustained_pct|80} AS sustained_pct,
  ${spin_avg_slice_us|200} AS spin_avg_slice_us,
  ${spin_switches_per_s|2000} AS spin_switches_per_s,
  ${waker_per_s|500} AS waker_per_s,
  ${kernel_daemon_share_pct|10} AS kernel_daemon_share_pct,
  printf('episode_drop_pct=%s;merge_gap_ms=%s;max_episodes=%s',
    ${episode_drop_pct|10}, ${merge_gap_ms|500}, ${max_episodes|3}) AS thresholds,
  e.evidence_scope
FROM system_cpu_freq_limit_episodes e CROSS JOIN observed_data_bounds db
ORDER BY impact_rank_score DESC, e.episode_start_ts
LIMIT ${max_episodes|3}
