-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|40}, 40), 1), 500) AS max_rows
)
SELECT
  COALESCE(p.name, printf('upid:%d', hgo.upid)) AS process_name,
  printf('%d', hgo.graph_sample_ts) AS graph_sample_ts,
  hgc.name AS class_name,
  hgo.self_size AS single_object_self_size,
  COUNT(*) AS occurrence_count,
  ROUND(SUM(hgo.self_size) / 1048576.0, 2) AS total_self_mb,
  SUM(CASE WHEN hgo.reachable THEN 1 ELSE 0 END) AS reachable_count
FROM heap_graph_object AS hgo
JOIN heap_graph_class AS hgc
  ON hgo.type_id = hgc.id
LEFT JOIN process AS p
  ON p.upid = hgo.upid
WHERE ('${process_name|}' = '' OR LOWER(COALESCE(p.name, '')) GLOB '*' || LOWER('${process_name|}') || '*')
  AND (${graph_sample_ts} IS NULL OR hgo.graph_sample_ts = ${graph_sample_ts})
GROUP BY hgo.upid, hgo.graph_sample_ts, hgc.name, hgo.self_size
ORDER BY occurrence_count DESC, total_self_mb DESC
LIMIT (SELECT max_rows FROM input)
