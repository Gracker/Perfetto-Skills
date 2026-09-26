-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: bb2e6b53cdde9eef70dca527316ceb2d87cdaed5c609cafd9ec516f76b3cd770
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  (SELECT COUNT(*) FROM android_heap_graph_stats) AS heap_graph_samples,
  (SELECT COUNT(*) FROM android_heap_graph_class_summary_tree) AS heap_graph_class_rows,
  objects.heap_graph_objects,
  objects.heap_graph_placeholder_objects,
  (SELECT COUNT(*) FROM heap_profile_allocation) AS heap_profile_allocations
FROM (
  SELECT
    COUNT(*) AS heap_graph_objects,
    COALESCE(SUM(self_size = -1), 0) AS heap_graph_placeholder_objects
  FROM heap_graph_object
) AS objects
