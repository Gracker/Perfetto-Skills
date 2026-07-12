-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  t.tid,
  t.name as thread_name,
  SUM(ss.dur) / 1e6 as cpu_time_ms,
  COUNT(*) as sched_count,
  ROUND(AVG(ss.dur) / 1e6, 3) as avg_slice_ms,
  CASE t.tid WHEN p.pid THEN 'main' ELSE 'worker' END as thread_type,
  -- 大核使用率
  ROUND(100.0 * SUM(CASE WHEN ct.core_type IN ('big', 'prime') THEN ss.dur ELSE 0 END) / NULLIF(SUM(ss.dur), 0), 1) as big_core_percent
FROM sched_slice ss
JOIN thread t ON ss.utid = t.utid
JOIN process p ON t.upid = p.upid
JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
WHERE p.upid = ${target_process.data[0].upid}
  AND (${start_ts} IS NULL OR ss.ts + ss.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ss.ts < ${end_ts})
GROUP BY t.utid
ORDER BY cpu_time_ms DESC
LIMIT 10
