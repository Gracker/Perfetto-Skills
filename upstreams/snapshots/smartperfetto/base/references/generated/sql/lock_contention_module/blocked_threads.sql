-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: d07a8840cdaf1f8b7ef019cfc13abd3529dc7873f677593f06d5892a1ddf859a

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
