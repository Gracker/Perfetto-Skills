-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: bbe145b95ab30fa9dd885a45be7807284558b2acb6ae49984bc6a0c137982397
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
