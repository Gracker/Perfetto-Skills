-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/scheduler_module.skill.yaml
-- Source SHA-256: 170b97c3038eea5585806c1247f48db789f2b92d188f5c6f46e5b928afe06452
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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
