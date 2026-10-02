-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: 173f88b137c8d74b94c90839398d803aea4e0f655a143d76102fe519e2094f68

SELECT
  gc_name as gc_type,
  dur / 1e6 as dur_ms,
  ts / 1e6 as ts_ms,
  thread_name,
  printf('%d', ts) as ts_str,
  printf('%d', dur) as dur_str,
  CASE WHEN is_main_thread = 1 THEN '是' ELSE '否' END as is_main_thread
FROM _gc_events
ORDER BY dur DESC
LIMIT 15
