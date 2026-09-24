-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/fragments/system_cpu_freq_limit_episode_verdicts.sql
-- Source SHA-256: 8212cb7e87c9c19b5eae2fc7b6273d6ab2f19a4b4fa4588ecd4510a3a75ea71b
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

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
