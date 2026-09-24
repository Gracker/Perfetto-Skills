-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_episode.skill.yaml
-- Source SHA-256: b02b4e752ee6809352b02fbf8267c6cd3900768a842fe46ba886cfc61a79bbbd
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

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
SELECT
  '${episode_id}' AS episode_id,
  ${policy_cpu} AS policy_cpu,
  '${core_type}' AS core_type,
  ${episode_start_ts} AS episode_start_ts,
  ${episode_end_ts} AS episode_end_ts,
  MAX(db.data_start_ts, ${episode_start_ts} - CAST(${lookback_ms|10000} * 1000000 AS INTEGER)) AS before_start_ts,
  ${episode_start_ts} AS before_end_ts,
  ${episode_start_ts} - MAX(db.data_start_ts, ${episode_start_ts} - CAST(${lookback_ms|10000} * 1000000 AS INTEGER)) AS before_window_ns,
  CASE WHEN ${episode_start_ts} - CAST(${lookback_ms|10000} * 1000000 AS INTEGER) < db.data_start_ts
    THEN 1 ELSE 0 END AS window_clipped_to_data_start,
  MAX(db.data_start_ts, ${episode_start_ts} - CAST(${who_window_ms|2000} * 1000000 AS INTEGER)) AS who_start_ts,
  MIN(db.data_end_ts, ${episode_start_ts} + CAST(${who_window_ms|2000} * 1000000 AS INTEGER)) AS who_end_ts,
  CASE WHEN ${episode_start_ts} - CAST(${who_window_ms|2000} * 1000000 AS INTEGER) < db.data_start_ts
    OR ${episode_start_ts} + CAST(${who_window_ms|2000} * 1000000 AS INTEGER) > db.data_end_ts
    THEN 1 ELSE 0 END AS who_window_clipped,
  ${starts_at_data_start|0} AS starts_at_data_start,
  db.data_start_ts, db.data_end_ts,
  printf('lookback_ms=%s;who_window_ms=%s;clipped_to_observed_data_bounds',
    ${lookback_ms|10000}, ${who_window_ms|2000}) AS window_basis
FROM observed_data_bounds db
