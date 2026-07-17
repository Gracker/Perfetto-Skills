-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_view.skill.yaml
-- Source SHA-256: 792f8e08be59730e2b62f9f21359ea7677b02b8ab7aa5224e5caaa9587779f76
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

CREATE PERFETTO TABLE _cpu_topology AS
WITH
observed_sched_cpus AS (
  SELECT cpu as cpu_id FROM sched_slice WHERE cpu IS NOT NULL
  UNION
  SELECT cpu as cpu_id
  FROM thread_state
  WHERE cpu IS NOT NULL AND state = 'Running'
),
observed_counter_cpus AS (
  SELECT t.cpu as cpu_id
  FROM cpu_counter_track t
  JOIN counter c ON c.track_id = t.id
  WHERE t.name = 'cpufreq'
    AND t.cpu IS NOT NULL
    AND c.value > 0
  GROUP BY t.cpu
),
cpu_universe AS (
  SELECT cpu_id, 'sched_observed' as universe_source
  FROM observed_sched_cpus
  UNION
  SELECT cpu_id, 'cpufreq_observed_fallback' as universe_source
  FROM observed_counter_cpus
  WHERE NOT EXISTS (SELECT 1 FROM observed_sched_cpus)
  UNION
  SELECT id as cpu_id, 'cpu_table_fallback_no_observed' as universe_source
  FROM cpu
  WHERE NOT EXISTS (SELECT 1 FROM observed_sched_cpus)
    AND NOT EXISTS (SELECT 1 FROM observed_counter_cpus)
),
cpu_capacity AS (
  SELECT
    cu.cpu_id,
    cu.universe_source,
    COALESCE(c.capacity, 0) as capacity
  FROM cpu_universe cu
  LEFT JOIN cpu c ON c.id = cu.cpu_id
),
cpu_max_freq AS (
  SELECT t.cpu as cpu_id, MAX(c.value) as max_freq
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  WHERE t.name = 'cpufreq'
    AND t.cpu IN (SELECT cpu_id FROM cpu_universe)
  GROUP BY t.cpu
),
selected_scale_source AS (
  SELECT
    CASE
      WHEN (SELECT COUNT(*) FROM cpu_capacity) > 0
        AND (SELECT COUNT(*) FROM cpu_capacity WHERE universe_source = 'cpu_table_fallback_no_observed') = 0
        AND (SELECT COUNT(*) FROM cpu_capacity WHERE capacity > 0) = (SELECT COUNT(*) FROM cpu_capacity)
        THEN 'capacity_scale'
      WHEN (SELECT COUNT(*) FROM cpu_capacity) > 0
        AND (SELECT COUNT(*) FROM cpu_capacity WHERE universe_source = 'cpu_table_fallback_no_observed') = 0
        AND (SELECT COUNT(*) FROM cpu_max_freq WHERE max_freq > 0) = (SELECT COUNT(*) FROM cpu_capacity)
        THEN 'freq_rank'
      ELSE 'observed_no_scale'
    END as source
),
raw_cpu_scale AS (
  SELECT
    cc.cpu_id,
    cc.universe_source,
    cc.capacity,
    cf.max_freq,
    CASE
      WHEN s.source = 'capacity_scale' THEN cc.capacity
      WHEN s.source = 'freq_rank' THEN cf.max_freq
      ELSE NULL
    END as scale_value,
    s.source as topology_source
  FROM cpu_capacity cc
  LEFT JOIN cpu_max_freq cf ON cc.cpu_id = cf.cpu_id
  CROSS JOIN selected_scale_source s
),
scale_bounds AS (
  SELECT MAX(scale_value) as max_scale
  FROM raw_cpu_scale
  WHERE scale_value > 0
),
cpu_scale AS (
  SELECT
    rs.*,
    CASE
      WHEN rs.scale_value > 0 AND (SELECT max_scale FROM scale_bounds) > 0
        THEN CAST(ROUND(rs.scale_value * 20.0 / (SELECT max_scale FROM scale_bounds)) AS INTEGER)
      ELSE NULL
    END as scale_bucket
  FROM raw_cpu_scale rs
),
distinct_scales AS (
  SELECT
    scale_bucket,
    avg_scale_value,
    ROW_NUMBER() OVER (ORDER BY scale_bucket ASC) as cluster_rank,
    COUNT(*) OVER () as cluster_count
  FROM (
    SELECT scale_bucket, AVG(scale_value) as avg_scale_value
    FROM cpu_scale
    WHERE scale_bucket IS NOT NULL AND scale_bucket > 0
    GROUP BY scale_bucket
  )
),
scale_clusters AS (
  SELECT
    ds.scale_bucket,
    ds.avg_scale_value,
    ds.cluster_rank,
    ds.cluster_count,
    COUNT(cs.cpu_id) as cores_in_cluster
  FROM distinct_scales ds
  JOIN cpu_scale cs ON cs.scale_bucket = ds.scale_bucket
  GROUP BY ds.scale_bucket, ds.avg_scale_value, ds.cluster_rank, ds.cluster_count
)
SELECT
  cs.cpu_id,
  cs.universe_source,
  cs.capacity,
  cs.max_freq,
  cs.scale_value,
  cs.scale_bucket,
  CASE
    WHEN cs.scale_bucket IS NULL OR cs.scale_bucket <= 0 THEN 'unknown'
    WHEN sc.cluster_count <= 1 AND (SELECT COUNT(*) FROM cpu_scale) <= 4 THEN 'little'
    WHEN sc.cluster_count <= 1 THEN 'unknown'
    WHEN sc.cluster_count = 2 AND sc.cluster_rank = sc.cluster_count THEN 'big'
    WHEN sc.cluster_rank = 1 THEN 'little'
    WHEN sc.cluster_rank = sc.cluster_count AND sc.cores_in_cluster = 1 THEN 'prime'
    WHEN sc.cluster_rank = sc.cluster_count THEN 'big'
    WHEN sc.cluster_rank = sc.cluster_count - 1
      AND (SELECT cores_in_cluster FROM scale_clusters WHERE cluster_rank = sc.cluster_count) = 1 THEN 'big'
    ELSE 'medium'
  END as core_type,
  CASE
    WHEN cs.scale_bucket IS NULL OR cs.scale_bucket <= 0 THEN cs.topology_source
    WHEN sc.cluster_count <= 1 AND (SELECT COUNT(*) FROM cpu_scale) <= 4 THEN cs.topology_source || '_uniform_four_little'
    WHEN sc.cluster_count <= 1 THEN cs.topology_source || '_uniform'
    ELSE cs.topology_source
  END as topology_source,
  sc.cluster_rank,
  sc.cluster_count,
  sc.cores_in_cluster
FROM cpu_scale cs
LEFT JOIN scale_clusters sc ON cs.scale_bucket = sc.scale_bucket
