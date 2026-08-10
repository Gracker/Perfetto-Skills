-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: d370620ee53fa3b255e1b519b9592a6780a0b2b9

SELECT
  'no_android_memory_v57_rows' AS status,
  heap_graph_samples,
  heap_profile_allocations
FROM ${data_check}
