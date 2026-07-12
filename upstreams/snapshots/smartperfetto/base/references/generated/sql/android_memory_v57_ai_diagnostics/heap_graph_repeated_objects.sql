-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|40}, 40), 1), 500) AS max_rows
)
SELECT
  COALESCE(p.name, printf('upid:%d', h.upid)) AS process_name,
  printf('%d', h.graph_sample_ts) AS graph_sample_ts,
  h.name AS class_name,
  COALESCE(h.root_type, '') AS root_type,
  COUNT(*) AS path_count,
  SUM(h.self_count) AS total_objects,
  ROUND(SUM(h.cumulative_size) / 1048576.0, 2) AS total_retained_mb,
  MIN(h.self_size) AS single_object_self_size,
  MIN(h.cumulative_size) AS single_object_cumulative_size
FROM android_heap_graph_class_summary_tree AS h
LEFT JOIN process AS p
  ON p.upid = h.upid
WHERE ('${process_name|}' = '' OR LOWER(COALESCE(p.name, '')) GLOB '*' || LOWER('${process_name|}') || '*')
  AND (${graph_sample_ts} IS NULL OR h.graph_sample_ts = ${graph_sample_ts})
GROUP BY h.upid, h.graph_sample_ts, h.name, h.root_type
ORDER BY path_count DESC, total_objects DESC, total_retained_mb DESC
LIMIT (SELECT max_rows FROM input)
