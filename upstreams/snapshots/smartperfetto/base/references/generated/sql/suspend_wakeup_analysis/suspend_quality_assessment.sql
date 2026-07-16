-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/suspend_wakeup_analysis.skill.yaml
-- Source SHA-256: cf54dd26038da1a8e319353fce7eef8b92cc4962e217cb1873d6bc9f74fa70ee
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH suspend_stats AS (
  SELECT
    SUM(CASE WHEN power_state = 'suspended' THEN dur ELSE 0 END) as suspended_time,
    SUM(CASE WHEN power_state = 'awake' THEN dur ELSE 0 END) as awake_time,
    SUM(dur) as total_time
  FROM android_suspend_state
  WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
wakeup_stats AS (
  SELECT
    COUNT(*) as total_wakeups,
    SUM(CASE WHEN type != 'normal' THEN 1 ELSE 0 END) as abort_count,
    SUM(CASE WHEN suspend_quality = 'bad' THEN 1 ELSE 0 END) as bad_quality_count,
    MAX(backoff_millis) as max_backoff_ms
  FROM android_wakeups
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
SELECT
  ROUND(ss.suspended_time * 100.0 / NULLIF(ss.total_time, 0), 2) as suspend_pct,
  ROUND(ss.awake_time * 100.0 / NULLIF(ss.total_time, 0), 2) as awake_pct,
  ws.total_wakeups,
  ROUND(ws.total_wakeups * 60e9 / NULLIF(ss.total_time, 0), 2) as wakeups_per_min,
  ws.abort_count,
  ws.bad_quality_count,
  ROUND(ws.abort_count * 100.0 / NULLIF(ws.total_wakeups, 0), 2) as abort_pct,
  ws.max_backoff_ms
FROM suspend_stats ss, wakeup_stats ws
