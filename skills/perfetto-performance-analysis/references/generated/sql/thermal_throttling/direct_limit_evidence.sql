-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: 5fad39740c373b463c8080622927249e67de2e731ea1cf79253d443663541c7e
-- Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad

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
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2024-2026 Gracker (Chris)

-- Input: system_windows(window_id, window_start_ts, window_end_ts).
-- Kernel cooling-device state from the ftrace event thermal/cdev_update, typed
-- as counter_track.type='cooling_device_counter'. The value is the requested
-- target state; 0 means the device is not cooling.
--
-- `cdev_kind_hint` is derived from the device NAME and is a hint only: the
-- kernel does not export the governed subsystem through this event, so the
-- hint cannot establish which policy a cooling device actually throttles.
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
thermal_cooling_raw AS (
  SELECT c.track_id AS cdev_track_id,
    c.id AS counter_id, c.ts, CAST(c.value AS INTEGER) AS state,
    CAST(LAG(c.value) OVER (PARTITION BY c.track_id ORDER BY c.ts, c.id) AS INTEGER) AS prev_state,
    LEAD(c.ts) OVER (PARTITION BY c.track_id ORDER BY c.ts, c.id) AS next_ts
  FROM counter c
  WHERE c.track_id IN (SELECT cdev_track_id FROM thermal_cooling_devices)
),
thermal_cooling_spans AS (
  SELECT w.window_id, w.window_start_ts, w.window_end_ts,
    d.cdev_name, d.cdev_kind_hint, d.cdev_kind_basis,
    r.counter_id, r.ts, r.state, r.prev_state,
    CASE
      WHEN r.prev_state IS NULL THEN 'first_observed_sample'
      WHEN r.state > r.prev_state THEN 'tightened'
      WHEN r.state < r.prev_state THEN 'relaxed'
      ELSE 'unchanged'
    END AS direction,
    r.state > 0 AS is_cooling_active,
    r.ts AS raw_start_ts,
    COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)) AS raw_end_ts,
    MAX(r.ts, w.window_start_ts) AS clipped_start_ts,
    MIN(COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)), w.window_end_ts) AS clipped_end_ts,
    MIN(COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)), w.window_end_ts)
      - MAX(r.ts, w.window_start_ts) AS dur_ns,
    r.ts < w.window_start_ts AS left_censored,
    r.next_ts IS NULL OR r.next_ts > w.window_end_ts AS right_censored,
    'ftrace:thermal/cdev_update' AS cooling_source
  FROM system_windows w
  JOIN thermal_cooling_raw r
    ON r.ts < w.window_end_ts
    AND COALESCE(r.next_ts, (SELECT end_ts FROM trace_bounds)) > w.window_start_ts
  JOIN thermal_cooling_devices d ON d.cdev_track_id = r.cdev_track_id
  WHERE w.window_end_ts > w.window_start_ts
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

-- Requires, injected in this order: observed_data_bounds.sql,
-- system_sched_spans.sql, system_cpu_freq_limit_spans.sql,
-- system_cpu_freq_limit_episodes.sql, thermal_cooling_spans.sql,
-- thermal_signal_signatures.sql.
-- Inputs: ${who_window_ms|2000}, ${cooling_coincidence_ms|50}.
--
-- One "who" reading per capped episode, on the same windows the episodes were
-- built from. Two cooling facts are kept apart on purpose:
--   coincident_transitions  a cooling-device step within cooling_coincidence_ms
--                           of the limit change: the kernel applying that cap;
--   cooling_spans           a device merely active while the episode ran:
--                           background cooling, much weaker.
-- `episode_verdict` ranks coincident transition > daemon activity before the
-- limit > background cooling > unknown onset > no thermal evidence.
-- cpu_frequency_limit_episode.who_verdict repeats this ladder with per-episode
-- detail; keep the branch order identical in both places.
_limit_episode_who_windows AS (
  SELECT e.window_id, e.episode_id, e.episode_start_ts, e.episode_end_ts,
    MAX(db.data_start_ts, e.episode_start_ts - CAST(${who_window_ms|2000} * 1000000 AS INTEGER)) AS who_start_ts,
    MIN(db.data_end_ts, e.episode_start_ts + CAST(${who_window_ms|2000} * 1000000 AS INTEGER)) AS who_end_ts
  FROM system_cpu_freq_limit_episodes e CROSS JOIN observed_data_bounds db
),
_limit_episode_cooling AS (
  SELECT w.window_id, w.episode_id,
    SUM(CASE WHEN s.is_cooling_active
      AND s.raw_start_ts < w.episode_end_ts
      AND s.raw_end_ts > w.episode_start_ts THEN 1 ELSE 0 END) AS cooling_spans,
    SUM(CASE WHEN s.direction IN ('tightened', 'relaxed')
      AND ABS(s.raw_start_ts - w.episode_start_ts)
        <= CAST(${cooling_coincidence_ms|50} * 1000000 AS INTEGER)
      THEN 1 ELSE 0 END) AS coincident_transitions
  FROM _limit_episode_who_windows w
  JOIN thermal_cooling_spans s ON s.window_id = w.window_id
  GROUP BY w.window_id, w.episode_id
),
_limit_episode_daemon AS (
  SELECT w.window_id, w.episode_id, COUNT(s.id) AS daemon_slices
  FROM _limit_episode_who_windows w
  JOIN thermal_daemon_threads d
  JOIN sched_slice s ON s.utid = d.utid AND s.dur > 0
    AND s.ts < w.episode_start_ts AND s.ts + s.dur > w.who_start_ts
  GROUP BY w.window_id, w.episode_id
),
system_cpu_freq_limit_episode_verdicts AS (
  SELECT e.*, w.who_start_ts, w.who_end_ts,
    COALESCE(c.cooling_spans, 0) AS cooling_spans,
    COALESCE(c.coincident_transitions, 0) AS coincident_transitions,
    COALESCE(d.daemon_slices, 0) AS daemon_slices,
    CASE
      WHEN COALESCE(c.coincident_transitions, 0) > 0 THEN 'thermal_cooling_device_confirmed'
      WHEN COALESCE(d.daemon_slices, 0) > 0 THEN 'userspace_thermal_daemon_active_before_limit'
      WHEN COALESCE(c.cooling_spans, 0) > 0 THEN 'thermal_cooling_device_confirmed'
      WHEN e.starts_at_data_start = 1 THEN 'onset_unknown_capped_at_data_start'
      ELSE 'limit_changed_no_thermal_evidence'
    END AS episode_verdict
  FROM system_cpu_freq_limit_episodes e
  JOIN _limit_episode_who_windows w ON w.window_id = e.window_id AND w.episode_id = e.episode_id
  LEFT JOIN _limit_episode_cooling c ON c.window_id = e.window_id AND c.episode_id = e.episode_id
  LEFT JOIN _limit_episode_daemon d ON d.window_id = e.window_id AND d.episode_id = e.episode_id
)
,
system_windows AS (
  SELECT 0 AS window_id,
    COALESCE(${start_ts}, (SELECT MIN(ts) FROM sched_slice), (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
)
SELECT
  COUNT(*) AS episode_count,
  COUNT(DISTINCT v.policy_cpu) AS policy_count,
  ROUND(MAX(v.depth_pct), 1) AS deepest_depth_pct,
  MAX(v.episode_dur_ns) AS longest_episode_ns,
  -- Overlap with an active cooling device, the weaker of the two cooling
  -- readings the fragment keeps; cpu_frequency_limit_attribution ranks
  -- the coincident transition above it.
  SUM(CASE WHEN v.cooling_spans > 0 THEN 1 ELSE 0 END) AS cooling_confirmed_episodes,
  SUM(CASE WHEN v.starts_at_data_start = 1 THEN 1 ELSE 0 END) AS onset_unknown_episodes,
  ${data_check.data[0].has_cdev_data|0} AS has_cdev_data,
  CASE
    WHEN SUM(CASE WHEN v.cooling_spans > 0 THEN 1 ELSE 0 END) > 0
      THEN 'confirmed_by_cooling_device'
    ELSE 'limit_observed_cause_unverified'
  END AS thermal_throttling_evidence,
  '用 cpu_frequency_limit_attribution 查看谁触发了限频、限频前的负载归因与异常线程' AS next_step,
  'observation_not_causal' AS evidence_scope
FROM system_cpu_freq_limit_episode_verdicts v
