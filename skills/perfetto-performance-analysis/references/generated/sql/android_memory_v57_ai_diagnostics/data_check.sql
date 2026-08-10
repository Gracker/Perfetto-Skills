-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: d370620ee53fa3b255e1b519b9592a6780a0b2b9

SELECT
  (SELECT COUNT(*) FROM android_heap_graph_stats) AS heap_graph_samples,
  (SELECT COUNT(*) FROM android_heap_graph_class_summary_tree) AS heap_graph_class_rows,
  (SELECT COUNT(*) FROM heap_graph_object) AS heap_graph_objects,
  (SELECT COUNT(*) FROM heap_profile_allocation) AS heap_profile_allocations,
  (SELECT COUNT(*) FROM android_heap_profile_summary_tree) AS heap_profile_summary_rows
