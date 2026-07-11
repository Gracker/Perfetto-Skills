-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/selection_range_cpu_sched_summary.skill.yaml
-- Source SHA-256: c970063c31991780a831d4c680bca4f241addf9eecef9565c54d93c113652151
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  COALESCE(p.name, '<unknown>') AS process_name,
  p.pid,
  ROUND(SUM(MIN(ts.ts + ts.dur, ${end_ts}) - MAX(ts.ts, ${start_ts})) / 1e6, 2) AS running_ms,
  COUNT(DISTINCT ts.utid) AS thread_count
FROM thread_state ts
JOIN thread t ON ts.utid = t.utid
LEFT JOIN process p ON t.upid = p.upid
WHERE ts.ts < ${end_ts}
  AND ts.ts + ts.dur > ${start_ts}
  AND ts.dur > 0
  AND ts.state = 'Running'
  AND ('${package|}' = '' OR COALESCE(p.name, '') GLOB '${package|}*')
  AND ('${thread_name|}' = '' OR COALESCE(t.name, '') GLOB '*${thread_name|}*')
GROUP BY p.upid
ORDER BY running_ms DESC
LIMIT ${top_k|20}
