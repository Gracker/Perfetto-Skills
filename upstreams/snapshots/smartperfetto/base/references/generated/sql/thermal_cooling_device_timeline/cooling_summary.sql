-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
-- Source SHA-256: 212c1203887256c5706a1e12c54ae6d163c0bb8647edd88afb0f73cc624cf16f
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

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
data_start AS (
  SELECT MIN(x) AS ts FROM (
    SELECT MIN(ts) AS x FROM sched_slice
    UNION ALL
    SELECT MIN(c.ts) FROM counter c JOIN counter_track t ON c.track_id = t.id
      WHERE t.type = 'cooling_device_counter'
  )
),
system_windows AS (
  SELECT 0 AS window_id,
    COALESCE(${start_ts}, (SELECT ts FROM data_start), (SELECT start_ts FROM trace_bounds)) AS window_start_ts,
    COALESCE(${end_ts}, (SELECT end_ts FROM trace_bounds)) AS window_end_ts
)
SELECT s.window_id, s.window_start_ts, s.window_end_ts,
  s.window_end_ts - s.window_start_ts AS window_dur_ns,
  s.cdev_name, MAX(s.cdev_kind_hint) AS cdev_kind_hint, MAX(s.cdev_kind_basis) AS cdev_kind_basis,
  MAX(s.state) AS max_state, MIN(s.state) AS min_state,
  ROUND(SUM(s.state * 1.0 * s.dur_ns) / NULLIF(SUM(s.dur_ns), 0), 2) AS mean_state,
  SUM(CASE WHEN s.direction IN ('tightened', 'relaxed') THEN 1 ELSE 0 END) AS transition_count,
  SUM(CASE WHEN s.is_cooling_active THEN s.dur_ns ELSE 0 END) AS active_ns,
  ROUND(100.0 * SUM(CASE WHEN s.is_cooling_active THEN s.dur_ns ELSE 0 END)
    / NULLIF(s.window_end_ts - s.window_start_ts, 0), 2) AS active_pct,
  MIN(s.raw_start_ts) AS first_ts, MAX(s.raw_start_ts) AS last_ts,
  SUM(s.dur_ns) AS covered_ns,
  CASE
    WHEN SUM(s.dur_ns) IS NULL THEN 'unavailable'
    WHEN SUM(s.dur_ns) < s.window_end_ts - s.window_start_ts THEN 'partial'
    ELSE 'observed'
  END AS cooling_evidence,
  MAX(s.cooling_source) AS cooling_source,
  'observation_not_causal' AS evidence_scope
FROM thermal_cooling_spans s
WHERE s.dur_ns > 0
GROUP BY s.window_id, s.window_start_ts, s.window_end_ts, s.cdev_name
ORDER BY active_ns DESC, max_state DESC
