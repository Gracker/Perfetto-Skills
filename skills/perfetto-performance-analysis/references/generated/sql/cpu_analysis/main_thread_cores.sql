-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.upid = ${target_process.data[0].upid} AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ss.cpu,
  ct.capacity,
  ct.core_type,
  SUM(ss.dur) / 1e6 as total_time_ms,
  ROUND(100.0 * SUM(ss.dur) / (
    SELECT SUM(ss2.dur) FROM sched_slice ss2
    WHERE ss2.utid = (SELECT utid FROM main_thread)
      AND (${start_ts} IS NULL OR ss2.ts + ss2.dur > ${start_ts})
      AND (${end_ts} IS NULL OR ss2.ts < ${end_ts})
  ), 1) as percent,
  COUNT(*) as slice_count
FROM sched_slice ss
JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
WHERE ss.utid = (SELECT utid FROM main_thread)
  AND (${start_ts} IS NULL OR ss.ts + ss.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ss.ts < ${end_ts})
GROUP BY ss.cpu
ORDER BY total_time_ms DESC
