-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wakeup_frequency_summary.skill.yaml
-- Source SHA-256: 0284882dd46c3d7d61c0a9efb203c61b2dbff2cc2710d0beb13652f985c9aa5c
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS start_ts,
    COALESCE(${end_ts}, trace_end()) AS end_ts
),
window AS (
  SELECT MAX((end_ts - start_ts) / 60e9, 0) AS window_min
  FROM bounds
),
device_wakeups AS (
  SELECT
    COUNT(*) AS wakeup_count,
    SUM(CASE WHEN suspend_quality = 'bad' THEN 1 ELSE 0 END) AS bad_wakeup_count
  FROM android_wakeups, bounds
  WHERE ts >= start_ts
    AND ts < end_ts
),
cpu_idle_exits AS (
  SELECT COUNT(*) AS idle_exit_count
  FROM cpu_idle_counters, bounds
  WHERE idle = -1
    AND ts >= start_ts
    AND ts < end_ts
)
SELECT
  ROUND(window_min, 2) AS window_min,
  wakeup_count AS device_wakeup_count,
  ROUND(wakeup_count / NULLIF(window_min, 0), 2) AS device_wakeups_per_min,
  idle_exit_count AS cpu_idle_exit_count,
  ROUND(idle_exit_count / NULLIF(window_min, 0), 2) AS cpu_idle_exits_per_min,
  bad_wakeup_count,
  CASE
    WHEN wakeup_count > 0 AND idle_exit_count > 0 THEN 'device_wakeup_and_cpu_idle_churn'
    WHEN wakeup_count > 0 THEN 'device_suspend_wakeups'
    WHEN idle_exit_count > 0 THEN 'cpu_idle_churn_only'
    ELSE 'no_wakeup_signal'
  END AS interpretation
FROM window, device_wakeups, cpu_idle_exits
