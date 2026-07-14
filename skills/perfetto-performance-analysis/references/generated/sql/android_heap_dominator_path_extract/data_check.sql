-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_heap_dominator_path_extract.skill.yaml
-- Source SHA-256: de4b9f64860789167409e6604441d8c932167169e8bed9c34ff6cbd580dc0daf
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  COUNT(DISTINCT printf('%d:%d', o.upid, o.graph_sample_ts)) AS sample_count,
  COUNT(*) AS object_count,
  CASE WHEN COUNT(*) > 0 THEN 'heap_graph_available' ELSE 'no_heap_graph_data' END AS status
FROM heap_graph_object AS o
LEFT JOIN process AS pr ON pr.upid = o.upid
WHERE (${upid} IS NULL OR o.upid = ${upid})
  AND ('${process_name|}' = '' OR LOWER(COALESCE(pr.name, '')) GLOB '*' || LOWER('${process_name|}') || '*')
  AND (${graph_sample_ts} IS NULL OR o.graph_sample_ts = ${graph_sample_ts})
