-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH gc_with_lag AS (
  SELECT
    ts,
    dur,
    LAG(ts + dur) OVER (ORDER BY ts) as prev_end
  FROM _gc_events
)
SELECT
  CASE
    WHEN (ts - prev_end) / 1e6 < 100 THEN '<100ms (频繁)'
    WHEN (ts - prev_end) / 1e6 < 500 THEN '100-500ms'
    WHEN (ts - prev_end) / 1e6 < 1000 THEN '500ms-1s'
    WHEN (ts - prev_end) / 1e6 < 5000 THEN '1-5s'
    ELSE '>5s'
  END as interval_bucket,
  COUNT(*) as count,
  ROUND(AVG(ts - prev_end) / 1e6, 2) as avg_interval_ms,
  ROUND(MIN(ts - prev_end) / 1e6, 2) as min_interval_ms
FROM gc_with_lag
WHERE prev_end IS NOT NULL
GROUP BY interval_bucket
ORDER BY
  CASE interval_bucket
    WHEN '<100ms (频繁)' THEN 1
    WHEN '100-500ms' THEN 2
    WHEN '500ms-1s' THEN 3
    WHEN '1-5s' THEN 4
    ELSE 5
  END
