-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  t.name AS thread_name,
  t.tid,
  ts.state,
  CAST(SUM(ts.dur) / 1e6 AS INTEGER) AS blocked_ms,
  COUNT(*) AS block_count,
  CAST(AVG(ts.dur) / 1e6 AS REAL) AS avg_block_ms,
  CAST(MAX(ts.dur) / 1e6 AS REAL) AS max_block_ms
FROM thread_state ts
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name LIKE '%${package}%'
  AND ts.state IN ('D', 'S')  -- Blocked or sleeping (could be lock wait)
  AND ts.dur > 1000000  -- > 1ms
GROUP BY t.utid, ts.state
HAVING blocked_ms > 5
ORDER BY blocked_ms DESC
LIMIT 20
