-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/lock_contention_in_range.skill.yaml
-- Source SHA-256: 5ab49bd436eb79f8d1bdc21b06e2b662481cb3335728c1776c55c8b0fab0f99b
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
monitor_stats AS (
  SELECT
    COUNT(*) as monitor_count,
    COALESCE(SUM(dur), 0) as monitor_total_ns,
    COALESCE(MAX(dur), 0) as monitor_max_ns,
    SUM(CASE WHEN is_blocked_thread_main THEN 1 ELSE 0 END) as monitor_main_blocked
  FROM android_monitor_contention
  WHERE ts >= ${start_ts}
    AND ts < ${end_ts}
    AND (process_name GLOB '${package}*' OR '${package}' = '')
),
futex_stats AS (
  SELECT
    COUNT(*) as futex_count,
    COALESCE(SUM(ts.dur), 0) as futex_total_ns,
    COALESCE(MAX(ts.dur), 0) as futex_max_ns,
    SUM(CASE WHEN t.tid = p.pid THEN 1 ELSE 0 END) as futex_main_blocked
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ts.ts >= ${start_ts}
    AND ts.ts < ${end_ts}
    AND (p.name GLOB '${package}*' OR '${package}' = '')
    AND ts.state IN ('S', 'D')
    AND ts.dur >= 1000000
    AND (ts.blocked_function GLOB '*futex*'
         OR ts.blocked_function GLOB '*mutex*')
)
SELECT
  (SELECT monitor_count FROM monitor_stats) as java_monitor_count,
  (SELECT futex_count FROM futex_stats) as futex_mutex_count,
  (SELECT monitor_count FROM monitor_stats) + (SELECT futex_count FROM futex_stats) as total_contentions,
  ROUND((SELECT monitor_total_ns FROM monitor_stats) / 1e6, 2) as java_monitor_wait_ms,
  ROUND((SELECT futex_total_ns FROM futex_stats) / 1e6, 2) as futex_mutex_wait_ms,
  ROUND(((SELECT monitor_total_ns FROM monitor_stats) + (SELECT futex_total_ns FROM futex_stats)) / 1e6, 2) as total_wait_ms,
  ROUND(((SELECT monitor_max_ns FROM monitor_stats) + 0) / 1e6, 2) as max_monitor_wait_ms,
  ROUND(((SELECT futex_max_ns FROM futex_stats) + 0) / 1e6, 2) as max_futex_wait_ms,
  (SELECT monitor_main_blocked FROM monitor_stats) + (SELECT futex_main_blocked FROM futex_stats) as main_thread_blocked_count
