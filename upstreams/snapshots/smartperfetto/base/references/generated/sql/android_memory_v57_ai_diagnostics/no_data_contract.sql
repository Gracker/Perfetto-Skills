-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: bb2e6b53cdde9eef70dca527316ceb2d87cdaed5c609cafd9ec516f76b3cd770
-- Source commit: 12f4004d5cdc2aeac76d3afce68ef2e3e87d500f

SELECT
  'no_android_memory_v57_rows' AS status,
  heap_graph_samples,
  heap_profile_allocations
FROM ${data_check}
