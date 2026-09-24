-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_episode.skill.yaml
-- Source SHA-256: b02b4e752ee6809352b02fbf8267c6cd3900768a842fe46ba886cfc61a79bbbd
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH
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
win AS (
  SELECT ${episode_windows.data[0].who_start_ts} AS who_start_ts,
    ${episode_windows.data[0].who_end_ts} AS who_end_ts
),
-- One window covering both the episode and its who-window, so the same
-- cooling spans answer "was cooling active during the episode" and "did a
-- cooling transition coincide with the limit change".
system_windows AS (
  SELECT 0 AS window_id,
    MIN(${episode_start_ts}, (SELECT who_start_ts FROM win)) AS window_start_ts,
    MAX(${episode_end_ts}, (SELECT who_end_ts FROM win)) AS window_end_ts
),
cooling AS (
  SELECT
    COALESCE(SUM(CASE WHEN s.is_cooling_active
      AND s.raw_start_ts < ${episode_end_ts}
      AND s.raw_end_ts > ${episode_start_ts} THEN s.dur_ns ELSE 0 END), 0) AS cooling_active_ns,
    COUNT(DISTINCT CASE WHEN s.is_cooling_active
      AND s.raw_start_ts < ${episode_end_ts}
      AND s.raw_end_ts > ${episode_start_ts} THEN s.cdev_name END) AS cooling_devices_active
  FROM thermal_cooling_spans s WHERE s.dur_ns > 0
),
cooling_transitions AS (
  SELECT s.raw_start_ts AS ts, ABS(s.raw_start_ts - ${episode_start_ts}) AS delta_ns
  FROM thermal_cooling_spans s
  WHERE s.direction IN ('tightened', 'relaxed')
    AND s.raw_start_ts >= (SELECT who_start_ts FROM win)
    AND s.raw_start_ts < (SELECT who_end_ts FROM win)
),
cooling_who AS (
  SELECT COUNT(*) AS cooling_transitions_in_who_window,
    MIN(delta_ns) AS cooling_nearest_transition_ns,
    (SELECT ts FROM cooling_transitions ORDER BY delta_ns LIMIT 1) AS cooling_nearest_transition_ts
  FROM cooling_transitions
),
daemon_activity AS (
  SELECT
    COALESCE(SUM(MIN(s.ts + s.dur, ${episode_start_ts}) - MAX(s.ts, (SELECT who_start_ts FROM win))), 0) AS daemon_ran_before_limit_ns,
    COUNT(DISTINCT s.utid) AS daemon_threads_before_limit
  FROM thermal_daemon_threads d JOIN sched_slice s ON s.utid = d.utid AND s.dur > 0
  WHERE s.ts < ${episode_start_ts} AND s.ts + s.dur > (SELECT who_start_ts FROM win)
),
facts AS (
  SELECT c.cooling_active_ns, c.cooling_devices_active,
    cw.cooling_transitions_in_who_window,
    cw.cooling_nearest_transition_ns, cw.cooling_nearest_transition_ts,
    d.daemon_ran_before_limit_ns, d.daemon_threads_before_limit,
    CASE WHEN cw.cooling_nearest_transition_ns IS NOT NULL
      AND cw.cooling_nearest_transition_ns <= CAST(${cooling_coincidence_ms|50} * 1000000 AS INTEGER)
      THEN 1 ELSE 0 END AS cooling_transition_coincident
  FROM cooling c CROSS JOIN cooling_who cw CROSS JOIN daemon_activity d
)
SELECT
  '${episode_id}' AS episode_id,
  ${policy_cpu} AS policy_cpu,
  '${core_type}' AS core_type,
  -- Ordering is deliberate. A cooling-device transition at the same
  -- instant as the limit change is the kernel thermal framework applying
  -- that cap. A daemon that ran just before it is the next best
  -- candidate. Cooling that was merely active in the background during
  -- the episode is weaker than both and is only used when nothing
  -- sharper is available.
  CASE
    WHEN f.cooling_transition_coincident = 1 THEN 'thermal_cooling_device_confirmed'
    WHEN f.daemon_ran_before_limit_ns > 0 THEN 'userspace_thermal_daemon_active_before_limit'
    WHEN f.cooling_active_ns > 0 THEN 'thermal_cooling_device_confirmed'
    WHEN ${starts_at_data_start|0} = 1 THEN 'onset_unknown_capped_at_data_start'
    ELSE 'limit_changed_no_thermal_evidence'
  END AS who_verdict,
  f.cooling_transition_coincident,
  f.cooling_nearest_transition_ns, f.cooling_nearest_transition_ts,
  f.cooling_active_ns, f.cooling_devices_active,
  f.cooling_transitions_in_who_window,
  f.daemon_ran_before_limit_ns, f.daemon_threads_before_limit,
  CASE WHEN ${starts_at_data_start|0} = 1 THEN 0 ELSE 1 END AS onset_observed,
  CASE WHEN ${starts_at_data_start|0} = 1
    THEN '区段首个样本即该轨道首个样本：限频起点在记录数据之外，不可观测'
    ELSE '限频起点落在记录数据之内' END AS onset_note,
  printf('who_window_ms=%s;cooling_coincidence_ms=%s',
    ${who_window_ms|2000}, ${cooling_coincidence_ms|50}) AS thresholds,
  printf('coincident=%d;nearest_transition_ns=%s;cooling_active_ns=%d;daemon_before_limit_ns=%d',
    f.cooling_transition_coincident,
    COALESCE(CAST(f.cooling_nearest_transition_ns AS TEXT), 'none'),
    f.cooling_active_ns, f.daemon_ran_before_limit_ns) AS verdict_basis,
  CASE
    WHEN f.cooling_transition_coincident = 1
      THEN '内核散热设备的档位变更与本次限频时刻重合：热控框架在此刻施加了抑温动作。cdev_update 事件不声明该设备治理的是哪个 cpufreq policy，对应关系仍需核对。'
    WHEN f.daemon_ran_before_limit_ns > 0
      THEN '限频前的归因窗口内有名字匹配温控守护签名的线程在运行：这是候选触发方，不是因果证明；该类守护进程在未限频时同样会周期性运行。'
    WHEN f.cooling_active_ns > 0
      THEN '区段期间内核散热设备处于非零档位，但没有与限频时刻重合的档位变更：属于并存的背景热控，不能确定是本次限频的施加者。'
    WHEN ${starts_at_data_start|0} = 1
      THEN '限频起点在数据之外，无法观测触发时刻；已有数据不足以判定触发方。'
    ELSE '限频发生了，但窗口内既没有内核散热设备活动，也没有匹配温控签名的守护进程活动：触发方未确定，可能是非热的策略限频，也可能是本 trace 未采集到相应事件。'
  END AS interpretation,
  'observation_not_causal' AS evidence_scope
FROM facts f
