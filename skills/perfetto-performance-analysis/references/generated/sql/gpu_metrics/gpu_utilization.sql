-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/gpu_metrics.skill.yaml
-- Source SHA-256: 7ec44d892abb05141d0c58bfb05944911a22d8a6d4252fc95aa9b12c5f4f800a
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
  ROUND(PERCENTILE(utilization, 0.95), 1) as p95_utilization_pct,
  COUNT(*) as sample_count,
  (SELECT GROUP_CONCAT(DISTINCT counter_name) FROM gpu_util) as util_counters
FROM gpu_util
WHERE utilization >= 0 AND utilization <= 100
