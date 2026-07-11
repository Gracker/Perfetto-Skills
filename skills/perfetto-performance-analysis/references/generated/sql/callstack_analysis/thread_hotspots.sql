-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: da6f8f053e7325fffa6983751eaebd17478c4ae924e86352ffd66e4101d98660
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

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
  '${package}' = '' OR p.name GLOB '${package}*'
GROUP BY t.utid
ORDER BY sample_count DESC
LIMIT 20
