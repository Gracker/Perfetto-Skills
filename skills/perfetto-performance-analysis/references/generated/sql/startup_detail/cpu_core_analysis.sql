-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: c893e468e06b0ae4f90ad99ba68cc341888c7cd9ad8159142e77dfc1b7903b32
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH main_thread AS (
  SELECT t.utid, t.tid, t.name as thread_name, p.pid, p.name as process_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*'
    AND t.tid = p.pid  -- 主线程
),
cpu_time AS (
  SELECT
    ss.utid,
    ss.cpu,
    SUM(
      MIN(ss.ts + ss.dur, ${end_ts}) - MAX(ss.ts, ${start_ts})
    ) / 1e6 as dur_ms,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM sched_slice ss
  JOIN main_thread mt ON ss.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.ts < ${end_ts}
    AND ss.ts + ss.dur > ${start_ts}
  GROUP BY ss.utid, ss.cpu
)
SELECT
  'MainThread' as thread_type,
  -- medium 核（如 Cortex-A78）性能足够，归入性能核侧
  ROUND(SUM(CASE WHEN core_type IN ('prime', 'big', 'medium') THEN dur_ms ELSE 0 END), 2) as big_core_ms,
  ROUND(SUM(CASE WHEN core_type IN ('little') THEN dur_ms ELSE 0 END), 2) as little_core_ms,
  ROUND(SUM(dur_ms), 2) as total_running_ms,
  ROUND(100.0 * SUM(CASE WHEN core_type IN ('prime', 'big', 'medium') THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as big_core_pct,
  ROUND(100.0 * SUM(CASE WHEN core_type IN ('little') THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as little_core_pct,
  GROUP_CONCAT(DISTINCT cpu) as used_cpus,
  'topology_view' as classify_method
FROM cpu_time
GROUP BY 1
