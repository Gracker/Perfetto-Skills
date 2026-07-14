-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: ca7ca4c40df11df499646b86be5c03ffef35d88535d034948b362516f1509118
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

SELECT
  t.name AS thread_name,
  SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) / 1e6 AS runnable_ms,
  SUM(CASE WHEN ts.state IN ('D', 'S') THEN ts.dur ELSE 0 END) / 1e6 AS blocked_ms,
  ROUND(SUM(CASE WHEN ts.state IN ('D', 'S') THEN ts.dur ELSE 0 END) * 100.0 /
        SUM(ts.dur), 2) AS blocked_pct
FROM thread_state ts
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name LIKE '%${package}%'
  AND t.name NOT LIKE '%Binder%'
  AND t.name NOT LIKE '%FinalizerDaemon%'
GROUP BY t.utid
HAVING blocked_pct > 20
ORDER BY blocked_ms DESC
LIMIT 15
