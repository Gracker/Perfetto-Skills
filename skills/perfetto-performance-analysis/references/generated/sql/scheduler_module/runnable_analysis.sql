-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
-- Source SHA-256: 0eb2ad71f21998edd7e7c48853cb90b76d0a623ccf3936bee6aa61310d955a88
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  utid,
  thread.name AS thread_name,
  CAST(SUM(dur) / 1e6 AS INTEGER) AS runnable_ms,
  COUNT(*) AS runnable_count,
  CAST(AVG(dur) / 1e6 AS REAL) AS avg_runnable_ms,
  CAST(MAX(dur) / 1e6 AS REAL) AS max_runnable_ms
FROM thread_state
JOIN thread USING (utid)
WHERE state = 'R'
  AND thread.name NOT LIKE '%Binder%'
  AND dur > 1000000  -- > 1ms
GROUP BY utid
ORDER BY runnable_ms DESC
LIMIT 20
