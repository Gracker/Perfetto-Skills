-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_topology_view.skill.yaml
-- Source SHA-256: 0e28eae312bbe09e5c3cc1e661392ed9e5814768117dbea99569f35bd3565dc6
-- Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5

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
  SELECT DISTINCT cpu as cpu_id, 'cpu_table_fallback_no_observed' as universe_source
  FROM cpu
  WHERE NOT EXISTS (SELECT 1 FROM observed_sched_cpus)
    AND NOT EXISTS (SELECT 1 FROM observed_counter_cpus)
),
machine_count AS (
  SELECT COUNT(*) as count FROM (SELECT machine_id FROM cpu GROUP BY machine_id)
),
cpu_metadata AS (
  SELECT cpu as cpu_id, COUNT(*) as metadata_rows, MIN(capacity) as capacity
  FROM cpu
  GROUP BY cpu
),
cpu_capacity AS (
  SELECT
    cu.cpu_id,
    cu.universe_source,
    CASE WHEN (SELECT count FROM machine_count) = 1 AND c.metadata_rows = 1
      THEN c.capacity ELSE NULL END as capacity,
    c.metadata_rows
  FROM cpu_universe cu
  LEFT JOIN cpu_metadata c ON c.cpu_id = cu.cpu_id
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
      WHEN (SELECT count FROM machine_count) > 1 THEN 'multi_machine_unresolved'
      WHEN EXISTS (SELECT 1 FROM cpu_capacity WHERE metadata_rows > 1) THEN 'ambiguous_cpu_metadata'
      WHEN (SELECT COUNT(*) FROM cpu_capacity) > 0
        AND (SELECT COUNT(*) FROM cpu_capacity WHERE universe_source = 'cpu_table_fallback_no_observed') = 0
        AND (SELECT COUNT(*) FROM cpu_capacity WHERE capacity > 0) = (SELECT COUNT(*) FROM cpu_capacity)
        THEN 'capacity_scale'
      ELSE 'observed_no_scale'
    END as source
),
raw_cpu_scale AS (
  SELECT
    cc.cpu_id,
    cc.universe_source,
    cc.capacity,
    CASE WHEN s.source IN ('multi_machine_unresolved', 'ambiguous_cpu_metadata')
      THEN NULL ELSE cf.max_freq END AS max_freq,
    CASE
      WHEN s.source = 'capacity_scale' THEN cc.capacity
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
    WHEN sc.cluster_count <= 1 THEN cs.topology_source || '_uniform'
    ELSE cs.topology_source
  END as topology_source,
  sc.cluster_rank,
  sc.cluster_count,
  sc.cores_in_cluster
FROM cpu_scale cs
LEFT JOIN scale_clusters sc ON cs.scale_bucket = sc.scale_bucket
