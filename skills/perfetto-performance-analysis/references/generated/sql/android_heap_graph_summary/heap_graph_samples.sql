-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_summary.skill.yaml
-- Source SHA-256: e4b8220ce04f7c700df3feb487e732421353aeda901ecc144e00008b8cc3b2d6
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  COALESCE(p.name, printf('upid:%d', stats.upid)) AS process_name,
  printf('%d', stats.graph_sample_ts) AS graph_sample_ts,
  ROUND(stats.reachable_heap_size / 1048576.0, 2) AS reachable_heap_mb,
  ROUND(stats.total_heap_size / 1048576.0, 2) AS total_heap_mb,
  stats.reachable_obj_count,
  stats.total_obj_count,
  ROUND(stats.anon_rss_and_swap_size / 1048576.0, 2) AS anon_rss_and_swap_mb,
  stats.oom_score_adj,
  ROUND(MAX(stats.total_heap_size - stats.reachable_heap_size, 0) / 1048576.0, 2) AS unreachable_heap_mb
FROM android_heap_graph_stats AS stats
LEFT JOIN process AS p
  ON p.upid = stats.upid
WHERE ('${process_name}' = '' OR p.name GLOB '*${process_name}*')
  AND (${graph_sample_ts} IS NULL OR stats.graph_sample_ts = ${graph_sample_ts})
ORDER BY stats.graph_sample_ts, stats.reachable_heap_size DESC
