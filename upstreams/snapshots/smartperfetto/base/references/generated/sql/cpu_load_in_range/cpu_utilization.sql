-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
-- Source SHA-256: 71e2b4436e6f0eb4a11f04bf71bfc3a9703ee7c738fb37d8ddf20f67ec7bc955
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
cpu_time AS (
  SELECT
    ss.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type,
    ss.utid,
    -- clamp dur 到范围内，处理跨边界的 sched_slice
    SUM(MIN(ss.ts + ss.dur, ${end_ts}) - MAX(ss.ts, ${start_ts})) as total_dur
  FROM sched_slice ss
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE (ss.ts + ss.dur) > ${start_ts}
    AND ss.ts < ${end_ts}
  GROUP BY ss.cpu, ss.utid
),
cpu_total AS (
  SELECT
    cpu,
    core_type,
    SUM(total_dur) as cpu_total_dur
  FROM cpu_time
  GROUP BY cpu
)
SELECT
  ct.core_type,
  COUNT(DISTINCT ct.cpu) as cpu_count,
  -- utid != 0 implies non-idle work in sched_slice (0 is usually swapper)
  ROUND(100.0 * SUM(CASE WHEN ctime.utid != 0 THEN ctime.total_dur ELSE 0 END) / NULLIF(SUM(ct.cpu_total_dur), 0), 1) as utilization_pct,
  ROUND(SUM(ct.cpu_total_dur) / 1e6, 2) as total_time_ms
FROM cpu_total ct
LEFT JOIN cpu_time ctime ON ct.cpu = ctime.cpu
GROUP BY ct.core_type
ORDER BY
  CASE ct.core_type
    WHEN 'prime' THEN 1
    WHEN 'big' THEN 2
    WHEN 'medium' THEN 3
    ELSE 4
  END
