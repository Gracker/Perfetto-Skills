-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 9456c4556e1e976ba2c42d7261839a9deac5ebd010487a69b95b965f094a68b2
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(c.ts)) as start_ts,
    COALESCE(${end_ts}, MAX(c.ts)) as end_ts
  FROM counter c
),
gpu_util AS (
  SELECT
    c.ts,
    c.value as utilization,
    t.name as counter_name
  FROM counter c
  JOIN gpu_counter_track t ON c.track_id = t.id
  WHERE (t.name GLOB '*util*' OR t.name GLOB '*Util*' OR t.name GLOB '*busy*' OR t.name GLOB '*Busy*')
    AND c.ts >= (SELECT start_ts FROM time_bounds)
    AND c.ts <= (SELECT end_ts FROM time_bounds)
)
SELECT
  ROUND(AVG(utilization), 1) as avg_utilization_pct,
  ROUND(MAX(utilization), 1) as max_utilization_pct,
  ROUND(MIN(utilization), 1) as min_utilization_pct,
  ROUND(PERCENTILE(utilization, 95), 1) as p95_utilization_pct,
  COUNT(*) as sample_count,
  (SELECT GROUP_CONCAT(DISTINCT counter_name) FROM gpu_util) as util_counters
FROM gpu_util
WHERE utilization >= 0 AND utilization <= 100
