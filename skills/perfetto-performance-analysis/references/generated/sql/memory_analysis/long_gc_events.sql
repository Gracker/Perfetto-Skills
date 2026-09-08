-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdf7ef77bd46ca7ff4ab49a48acc199332397fade61d1e9cbc71b3270f4f8bc4
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
