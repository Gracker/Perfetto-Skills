-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/selection_range_cpu_sched_summary.skill.yaml
-- Source SHA-256: 31127ebb648421f06248c4ceb054d614d12df318c63b0a652a41f341b556310e
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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
