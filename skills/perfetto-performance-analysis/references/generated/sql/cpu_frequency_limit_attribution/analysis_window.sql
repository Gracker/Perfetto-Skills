-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_frequency_limit_attribution.skill.yaml
-- Source SHA-256: 9b27b3315b361c5cd21809d36d2415240a89ae8baf023b849ee3a4a8ba068888
-- Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df

WITH data_bounds AS (
  SELECT
    COALESCE(
      (SELECT MIN(ts) FROM sched_slice),
      (SELECT MIN(c.ts) FROM counter c JOIN cpu_counter_track t ON c.track_id = t.id
        WHERE t.type IN ('cpu_max_frequency_limit', 'cpu_min_frequency_limit')),
      (SELECT start_ts FROM trace_bounds)) AS data_start_ts,
    (SELECT end_ts FROM trace_bounds) AS data_end_ts
)
SELECT
  COALESCE(${start_ts}, db.data_start_ts) AS window_start_ts,
  COALESCE(${end_ts}, db.data_end_ts) AS window_end_ts,
  COALESCE(${end_ts}, db.data_end_ts) - COALESCE(${start_ts}, db.data_start_ts) AS window_dur_ns,
  CASE WHEN ${start_ts} IS NOT NULL OR ${end_ts} IS NOT NULL
    THEN 'user_selected' ELSE 'observed_data_range' END AS window_source,
  db.data_start_ts, db.data_end_ts,
  'data_start = min(sched_slice.ts, first cpufreq limit sample); data_end = trace_bounds.end_ts' AS window_basis
FROM data_bounds db
