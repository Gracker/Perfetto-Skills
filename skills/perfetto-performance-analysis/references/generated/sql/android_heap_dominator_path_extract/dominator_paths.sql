-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_heap_dominator_path_extract.skill.yaml
-- Source SHA-256: de4b9f64860789167409e6604441d8c932167169e8bed9c34ff6cbd580dc0daf
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

CREATE OR REPLACE PERFETTO TABLE __sp_heap_dominator_cumulatives AS
SELECT *
FROM _graph_aggregating_scan!(
  (
    SELECT id AS source_node_id, parent_id AS dest_node_id
    FROM _heap_graph_dominator_class_tree
    WHERE parent_id IS NOT NULL
  ),
  (
    SELECT
      parent.id,
      parent.self_count AS cumulative_count,
      parent.self_size AS cumulative_size
    FROM _heap_graph_dominator_class_tree AS parent
    LEFT JOIN _heap_graph_dominator_class_tree AS child
      ON child.parent_id = parent.id
    WHERE child.id IS NULL
  ),
  (cumulative_count, cumulative_size),
  (
    WITH child_totals AS (
      SELECT
        id,
        SUM(cumulative_count) AS cumulative_count,
        SUM(cumulative_size) AS cumulative_size
      FROM $table
      GROUP BY id
    )
    SELECT
      child_totals.id,
      child_totals.cumulative_count + node.self_count AS cumulative_count,
      child_totals.cumulative_size + node.self_size AS cumulative_size
    FROM child_totals
    JOIN _heap_graph_dominator_class_tree AS node USING (id)
  )
);

CREATE OR REPLACE PERFETTO TABLE __sp_heap_top_dominator_nodes AS
SELECT id
FROM (
  SELECT
    tree.id,
    ROW_NUMBER() OVER (
      PARTITION BY tree.upid, tree.graph_sample_ts
      ORDER BY tree.self_size DESC, cumulative.cumulative_size DESC, tree.id
    ) AS row_number
  FROM _heap_graph_dominator_class_tree AS tree
  JOIN __sp_heap_dominator_cumulatives AS cumulative USING (id)
  LEFT JOIN process AS pr ON pr.upid = tree.upid
  WHERE (${upid} IS NULL OR tree.upid = ${upid})
    AND ('${process_name|}' = '' OR LOWER(COALESCE(pr.name, '')) GLOB '*' || LOWER('${process_name|}') || '*')
    AND (${graph_sample_ts} IS NULL OR tree.graph_sample_ts = ${graph_sample_ts})
)
WHERE row_number = 1;

CREATE OR REPLACE PERFETTO TABLE __sp_heap_dominator_ancestor_ids AS
SELECT id
FROM _tree_reachable_ancestors_or_self!((
  SELECT id, parent_id FROM _heap_graph_dominator_class_tree
), (SELECT id FROM __sp_heap_top_dominator_nodes));

CREATE OR REPLACE PERFETTO TABLE __sp_heap_dominator_labels AS
SELECT
  tree.id,
  tree.parent_id,
  IFNULL(tree.name, '[Unknown]') || ' [' || tree.self_count || ']' AS label,
  tree.root_type
FROM _heap_graph_dominator_class_tree AS tree
JOIN __sp_heap_dominator_ancestor_ids AS ancestor USING (id);

CREATE OR REPLACE PERFETTO TABLE __sp_heap_dominator_paths AS
WITH RECURSIVE paths(id, path, root_type) AS (
  SELECT
    id,
    '[' || COALESCE(root_type, 'ROOT') || '] ' || label AS path,
    COALESCE(root_type, 'ROOT') AS root_type
  FROM __sp_heap_dominator_labels
  WHERE parent_id IS NULL
  UNION ALL
  SELECT
    child.id,
    parent.path || ' -> ' || child.label AS path,
    parent.root_type
  FROM paths AS parent
  JOIN __sp_heap_dominator_labels AS child ON child.parent_id = parent.id
)
SELECT id, path, root_type
FROM paths;

WITH input AS (
  SELECT MIN(MAX(COALESCE(${max_rows|500}, 500), 1), 500) AS max_rows
)
SELECT
  tree.upid AS upid,
  COALESCE(pr.name, printf('upid:%d', tree.upid)) AS process_name,
  printf('%d', tree.graph_sample_ts) AS graph_sample_ts,
  COALESCE(p.path, '[ROOT] ' || COALESCE(tree.name, '[Unknown]')) AS path,
  COALESCE(tree.name, '[Unknown]') AS class_name,
  COALESCE(p.root_type, 'ROOT') AS root_type,
  tree.self_count AS self_count,
  c.cumulative_count AS retained_count,
  tree.self_size AS self_size_bytes,
  c.cumulative_size AS retained_size_bytes
FROM __sp_heap_top_dominator_nodes AS top
JOIN _heap_graph_dominator_class_tree AS tree ON tree.id = top.id
JOIN __sp_heap_dominator_cumulatives AS c ON c.id = top.id
LEFT JOIN __sp_heap_dominator_paths AS p ON p.id = top.id
LEFT JOIN process AS pr ON pr.upid = tree.upid
ORDER BY c.cumulative_size DESC, tree.self_size DESC, p.path
LIMIT (SELECT max_rows FROM input)
