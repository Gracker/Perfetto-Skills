-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  (SELECT COUNT(*) FROM android_heap_graph_stats) AS heap_graph_samples,
  (SELECT COUNT(*) FROM android_heap_graph_class_summary_tree) AS heap_graph_class_rows,
  (SELECT COUNT(*) FROM heap_graph_object) AS heap_graph_objects,
  (SELECT COUNT(*) FROM heap_profile_allocation) AS heap_profile_allocations,
  (SELECT COUNT(*) FROM android_heap_profile_summary_tree) AS heap_profile_summary_rows
