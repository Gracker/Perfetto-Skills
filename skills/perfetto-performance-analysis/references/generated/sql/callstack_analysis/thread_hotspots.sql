-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: fc08d54c591a45a1488f7d1064504f08f7d3d2fa95b42eec2a1c6da725ec5f08
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  t.name as thread_name,
  t.tid,
  p.name as process_name,
  COUNT(*) as sample_count,
  ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM perf_sample), 0), 2) as percentage
FROM perf_sample ps
JOIN thread t ON ps.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE
  '${package}' = '' OR ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
GROUP BY t.utid
ORDER BY sample_count DESC
LIMIT 20
