-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/memory_analysis.skill.yaml
-- Source SHA-256: cdec84f3101148083ffa1b4e4d4fd0fd16bfcac16c0a71b257ca50f86c84311c
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
