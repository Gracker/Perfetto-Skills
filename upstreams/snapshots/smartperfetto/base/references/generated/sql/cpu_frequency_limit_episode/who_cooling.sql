-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_episode.skill.yaml
-- Source SHA-256: b02b4e752ee6809352b02fbf8267c6cd3900768a842fe46ba886cfc61a79bbbd
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
system_windows AS (
  SELECT 0 AS window_id,
    ${episode_windows.data[0].who_start_ts} AS window_start_ts,
    ${episode_windows.data[0].who_end_ts} AS window_end_ts
)
SELECT s.raw_start_ts AS ts,
  s.raw_start_ts - ${episode_start_ts} AS rel_to_limit_ns,
  s.cdev_name, s.cdev_kind_hint, s.cdev_kind_basis,
  s.prev_state, s.state, s.direction, s.dur_ns, s.cooling_source,
  'observation_not_causal' AS evidence_scope
FROM thermal_cooling_spans s
WHERE s.raw_start_ts >= s.window_start_ts AND s.raw_start_ts < s.window_end_ts
ORDER BY ABS(s.raw_start_ts - ${episode_start_ts})
LIMIT 50
