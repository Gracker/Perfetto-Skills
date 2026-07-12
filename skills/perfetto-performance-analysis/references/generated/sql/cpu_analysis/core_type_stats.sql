-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  CASE ct.core_type
    WHEN 'prime' THEN 'prime (超大核)'
    WHEN 'big' THEN 'big (大核)'
    WHEN 'medium' THEN 'medium (中核)'
    ELSE 'little (小核)'
  END as core_type,
  ct.capacity,
  SUM(ss.dur) / 1e6 as total_time_ms,
  ROUND(100.0 * SUM(ss.dur) / (
    SELECT SUM(dur) FROM sched_slice ss2
    JOIN thread t2 ON ss2.utid = t2.utid
    JOIN process p2 ON t2.upid = p2.upid
    WHERE p2.upid = ${target_process.data[0].upid}
      AND (${start_ts} IS NULL OR ss2.ts + ss2.dur > ${start_ts})
      AND (${end_ts} IS NULL OR ss2.ts < ${end_ts})
  ), 1) as percent,
  COUNT(*) as slice_count,
  COUNT(DISTINCT ss.cpu) as core_count
FROM sched_slice ss
JOIN thread t ON ss.utid = t.utid
JOIN process p ON t.upid = p.upid
JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
WHERE p.upid = ${target_process.data[0].upid}
  AND (${start_ts} IS NULL OR ss.ts + ss.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ss.ts < ${end_ts})
GROUP BY ct.core_type
ORDER BY ct.capacity DESC
