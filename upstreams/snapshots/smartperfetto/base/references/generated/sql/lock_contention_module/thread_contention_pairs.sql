-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 106819ab92ac89738c756cd296dd1da8aac142910477fdb313a8dc616a50bd08

SELECT
  t.name AS thread_name,
  SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) / 1e6 AS runnable_ms,
  SUM(CASE WHEN ts.state IN ('D', 'S') THEN ts.dur ELSE 0 END) / 1e6 AS blocked_ms,
  ROUND(SUM(CASE WHEN ts.state IN ('D', 'S') THEN ts.dur ELSE 0 END) * 100.0 /
        SUM(ts.dur), 2) AS blocked_pct
FROM thread_state ts
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
  AND t.name NOT LIKE '%Binder%'
  AND t.name NOT LIKE '%FinalizerDaemon%'
GROUP BY t.utid
HAVING blocked_pct > 20
ORDER BY blocked_ms DESC
LIMIT 15
