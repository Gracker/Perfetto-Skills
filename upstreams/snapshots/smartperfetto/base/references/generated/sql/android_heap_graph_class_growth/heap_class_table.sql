-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_class_growth.skill.yaml
-- Source SHA-256: 7f3005702a7a0b160c86748bb1b535119fb9647f5d1bfa60496bf33c11551a55
-- Source commit: 459063305709d69ae0a322371bba3f506c41c62c

-- One table for every step below, one row per (process, dump, class
-- name). Counts and shallow sizes come from real objects only; the
-- stdlib aggregation groups placeholders by type_id 0, which belongs to
-- whichever class was inserted first, so it supplies dominated sizes
-- only. type_ids are per dump, so class names are the cross-dump key.
CREATE OR REPLACE PERFETTO TABLE __sp_heap_class_growth_classes AS
WITH per_type AS (
  -- Integer keys first; class names are joined on the small result.
  SELECT
    upid,
    graph_sample_ts,
    type_id,
    COUNT(*) AS obj_count,
    SUM(self_size) AS size_bytes,
    SUM(IIF(reachable, 1, 0)) AS reachable_obj_count,
    SUM(IIF(reachable, self_size, 0)) AS reachable_size_bytes
  FROM heap_graph_object
  WHERE self_size >= 0
  GROUP BY upid, graph_sample_ts, type_id
),
objects AS (
  SELECT
    t.upid,
    t.graph_sample_ts,
    COALESCE(c.deobfuscated_name, c.name, '[unknown class]') AS class_name,
    SUM(t.obj_count) AS obj_count,
    SUM(t.size_bytes) AS size_bytes,
    SUM(t.reachable_obj_count) AS reachable_obj_count,
    SUM(t.reachable_size_bytes) AS reachable_size_bytes,
    COUNT(*) AS type_id_count
  FROM per_type AS t
  JOIN heap_graph_class AS c ON c.id = t.type_id
  GROUP BY t.upid, t.graph_sample_ts, class_name
),
dominated AS (
  SELECT
    upid,
    graph_sample_ts,
    COALESCE(type_name, '[unknown class]') AS class_name,
    SUM(dominated_obj_count) AS dominated_obj_count,
    SUM(dominated_size_bytes + dominated_native_size_bytes) AS dominated_bytes
  FROM android_heap_graph_class_aggregation
  GROUP BY upid, graph_sample_ts, class_name
)
SELECT
  o.*,
  _is_libcore_or_array(o.class_name) AS is_libcore_or_array,
  COALESCE(d.dominated_obj_count, 0) AS dominated_obj_count,
  COALESCE(d.dominated_bytes, 0) AS dominated_bytes
FROM objects AS o
LEFT JOIN dominated AS d USING (upid, graph_sample_ts, class_name);

-- Later steps probe this table per (dump, class); real dumps have tens of
-- thousands of classes each.
CREATE OR REPLACE PERFETTO INDEX __sp_heap_class_growth_classes_idx
ON __sp_heap_class_growth_classes(upid, graph_sample_ts, class_name);

SELECT COUNT(*) AS class_row_count FROM __sp_heap_class_growth_classes
