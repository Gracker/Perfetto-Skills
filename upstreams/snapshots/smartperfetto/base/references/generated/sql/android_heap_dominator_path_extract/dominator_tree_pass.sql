-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_heap_dominator_path_extract.skill.yaml
-- Source SHA-256: 79a6054d4d6744e18381baa97106c13e0a4e11f4c8655ba9ade28004904aab52
-- Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5

-- Trace processors up to v58.2 sum self_size = -1 placeholder objects
-- into class nodes; clamp so an incomplete dump can never go negative.
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
      MAX(parent.self_size, 0) AS cumulative_size
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
      child_totals.cumulative_size + MAX(node.self_size, 0) AS cumulative_size
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
      ORDER BY MAX(tree.self_size, 0) DESC, cumulative.cumulative_size DESC, tree.id
    ) AS row_number
  FROM _heap_graph_dominator_class_tree AS tree
  JOIN __sp_heap_dominator_cumulatives AS cumulative USING (id)
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

SELECT COUNT(*) AS top_node_count FROM __sp_heap_top_dominator_nodes
