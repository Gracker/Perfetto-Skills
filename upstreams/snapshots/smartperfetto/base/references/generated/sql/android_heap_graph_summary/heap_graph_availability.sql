-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_summary.skill.yaml
-- Source SHA-256: e4b8220ce04f7c700df3feb487e732421353aeda901ecc144e00008b8cc3b2d6
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  COUNT(*) AS sample_count,
  COUNT(DISTINCT stats.upid) AS process_count,
  ROUND(COALESCE(SUM(stats.reachable_heap_size), 0) / 1048576.0, 2) AS reachable_heap_mb,
  ROUND(COALESCE(SUM(stats.total_heap_size), 0) / 1048576.0, 2) AS total_heap_mb,
  CASE WHEN COUNT(*) > 0 THEN 'heap_graph_available' ELSE 'no_heap_graph_data' END AS status
FROM android_heap_graph_stats AS stats
LEFT JOIN process AS p
  ON p.upid = stats.upid
WHERE ('${process_name}' = '' OR p.name GLOB '*${process_name}*')
  AND (${graph_sample_ts} IS NULL OR stats.graph_sample_ts = ${graph_sample_ts})
