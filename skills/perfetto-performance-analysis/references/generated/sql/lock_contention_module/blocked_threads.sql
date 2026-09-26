-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 693f6663e128d50376bf9b5d140720a74789e0354b6c784ed0a7b1d8ddd85bd5
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
