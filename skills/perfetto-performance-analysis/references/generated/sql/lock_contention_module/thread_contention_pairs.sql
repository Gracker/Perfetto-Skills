-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/kernel/lock_contention_module.skill.yaml
-- Source SHA-256: 693f6663e128d50376bf9b5d140720a74789e0354b6c784ed0a7b1d8ddd85bd5
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

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
