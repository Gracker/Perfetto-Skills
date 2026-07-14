-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

SELECT
  (SELECT COUNT(*) FROM android_heap_graph_stats) AS heap_graph_samples,
  (SELECT COUNT(*) FROM android_heap_graph_class_summary_tree) AS heap_graph_class_rows,
  (SELECT COUNT(*) FROM heap_graph_object) AS heap_graph_objects,
  (SELECT COUNT(*) FROM heap_profile_allocation) AS heap_profile_allocations,
  (SELECT COUNT(*) FROM android_heap_profile_summary_tree) AS heap_profile_summary_rows
