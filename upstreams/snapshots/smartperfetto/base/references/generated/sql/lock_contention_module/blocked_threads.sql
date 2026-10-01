-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 106819ab92ac89738c756cd296dd1da8aac142910477fdb313a8dc616a50bd08

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
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND ts.state IN ('D', 'S')  -- Blocked or sleeping (could be lock wait)
  AND ts.dur > 1000000  -- > 1ms
GROUP BY t.utid, ts.state
HAVING blocked_ms > 5
ORDER BY blocked_ms DESC
LIMIT 20
