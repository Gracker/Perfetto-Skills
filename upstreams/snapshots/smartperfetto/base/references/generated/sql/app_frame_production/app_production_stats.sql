-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/app_frame_production.skill.yaml
-- Source SHA-256: f7c24d6aa56cc29422e948867cc203415f06ff4182964dd3fc594aa23a3be29a
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH
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
matched_frames AS (
  SELECT
    a.upid,
    e.ts as expected_ts,
    e.dur as expected_dur,
    a.ts as actual_ts,
    a.dur as actual_dur,
    a.jank_type,
    p.name as process_name
  FROM expected_frame_timeline_slice e
  JOIN actual_frame_timeline_slice a
    ON e.display_frame_token = a.display_frame_token
    AND e.upid = a.upid
  JOIN effective_target_processes p ON e.upid = p.upid
  WHERE (${__process_scope.upid} IS NOT NULL OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
),
-- The authored window selects expected frame starts. Derive automatic
-- bounds from the same clock so a late actual start cannot drop frame 1.
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(expected_ts)) as start_ts,
    COALESCE(${end_ts}, MAX(expected_ts + expected_dur)) as end_ts
  FROM matched_frames
),
app_frames AS (
  SELECT
    *,
    LAG(expected_ts) OVER (PARTITION BY upid ORDER BY expected_ts) as prev_expected_ts,
    LAG(actual_ts) OVER (PARTITION BY upid ORDER BY actual_ts) as prev_actual_ts
  FROM matched_frames
  WHERE expected_ts >= (SELECT start_ts FROM time_bounds)
    AND expected_ts <= (SELECT end_ts FROM time_bounds)
),
production_intervals AS (
  SELECT
    expected_ts - prev_expected_ts as expected_interval_ns,
    actual_ts - prev_actual_ts as actual_interval_ns,
    actual_dur,
    jank_type
  FROM app_frames
  WHERE prev_expected_ts IS NOT NULL
),
production_stats AS (
  SELECT
    COUNT(*) as total_produced_frames,
    (SELECT end_ts - start_ts FROM time_bounds) as total_duration_ns,
    COUNT(CASE WHEN jank_type = 'None' THEN 1 END) as on_time_frames,
    COUNT(CASE WHEN jank_type != 'None' THEN 1 END) as janky_frames,
    (SELECT AVG(expected_interval_ns) FROM production_intervals) as avg_expected_interval_ns,
    AVG(actual_dur) as avg_actual_dur_ns,
    MAX(actual_dur) as max_actual_dur_ns
  FROM app_frames
)
SELECT
  total_produced_frames,
  ROUND(total_duration_ns / 1e6, 1) as duration_ms,
  on_time_frames,
  janky_frames,
  ROUND(100.0 * janky_frames / NULLIF(total_produced_frames, 0), 2) as app_jank_rate,
  ROUND(1e9 * total_produced_frames / NULLIF(total_duration_ns, 0), 1) as production_fps,
  ROUND(1e9 / NULLIF(avg_expected_interval_ns, 0), 1) as expected_fps,
  ROUND(avg_actual_dur_ns / 1e6, 2) as avg_frame_dur_ms,
  ROUND(max_actual_dur_ns / 1e6, 2) as max_frame_dur_ms,
  'app_production' as metric_source
FROM production_stats
