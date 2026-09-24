-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

SELECT
  'no_android_memory_v57_rows' AS status,
  heap_graph_samples,
  heap_profile_allocations
FROM ${data_check}
