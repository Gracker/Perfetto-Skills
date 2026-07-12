-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_summary.skill.yaml
-- Source SHA-256: e4b8220ce04f7c700df3feb487e732421353aeda901ecc144e00008b8cc3b2d6
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH sample_totals AS (
  SELECT
    upid,
    graph_sample_ts,
    reachable_heap_size
  FROM android_heap_graph_stats
)
SELECT
  COALESCE(p.name, printf('upid:%d', classes.upid)) AS process_name,
  printf('%d', classes.graph_sample_ts) AS graph_sample_ts,
  classes.name AS class_name,
  classes.root_type,
  classes.self_count,
  ROUND(classes.self_size / 1048576.0, 2) AS self_size_mb,
  classes.cumulative_count,
  ROUND(classes.cumulative_size / 1048576.0, 2) AS cumulative_size_mb,
  ROUND(100.0 * classes.cumulative_size / NULLIF(sample_totals.reachable_heap_size, 0), 2) AS retained_pct_of_sample,
  CASE
    WHEN classes.root_type IN ('ROOT_JAVA_FRAME', 'ROOT_JNI_GLOBAL') AND classes.cumulative_size > 1048576 THEN 'root_retainer'
    WHEN classes.name GLOB '*Activity*' AND classes.self_count > 1 THEN 'activity_instances'
    WHEN classes.name GLOB '*Fragment*' AND classes.self_count > 5 THEN 'fragment_instances'
    WHEN classes.cumulative_size > sample_totals.reachable_heap_size * 0.2 THEN 'dominant_retainer'
    ELSE 'inspect_if_relevant'
  END AS leak_hint
FROM android_heap_graph_class_summary_tree AS classes
JOIN sample_totals
  ON sample_totals.upid = classes.upid
  AND sample_totals.graph_sample_ts = classes.graph_sample_ts
LEFT JOIN process AS p
  ON p.upid = classes.upid
WHERE ('${process_name}' = '' OR p.name GLOB '*${process_name}*')
  AND (${graph_sample_ts} IS NULL OR classes.graph_sample_ts = ${graph_sample_ts})
ORDER BY classes.cumulative_size DESC
LIMIT COALESCE(${max_rows|30}, 30)
