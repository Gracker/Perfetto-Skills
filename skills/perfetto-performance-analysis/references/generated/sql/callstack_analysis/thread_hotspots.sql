-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/callstack_analysis.skill.yaml
-- Source SHA-256: 32723ee660e8cc822dc7b98136a23b15ba55fc88f77942c0ee0b658a654680f1
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

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
