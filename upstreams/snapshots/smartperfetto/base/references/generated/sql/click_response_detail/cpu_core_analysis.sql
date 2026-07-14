-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_detail.skill.yaml
-- Source SHA-256: 3bf411e6c0f6db9de2434fb0ad420cb0a0140388c5968306f5ad569b3ff0c3e7
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND t.tid = p.pid
),
-- 检测拓扑分类来源（用于诊断置信度判断）
topology_meta AS (
  SELECT
    CASE
      WHEN MAX(ct.capacity) > 0 THEN 'capacity'
      WHEN EXISTS (SELECT 1 FROM cpu_counter_track WHERE name = 'cpufreq' LIMIT 1) THEN 'freq_rank'
      ELSE 'cpu_id_fallback'
    END as classify_method
  FROM _cpu_topology ct
),
cpu_time AS (
  SELECT
    ss.cpu,
    SUM(
      MIN(ss.ts + ss.dur, ${event_end_ts}) - MAX(ss.ts, ${event_ts})
    ) / 1e6 as dur_ms,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM sched_slice ss
  JOIN main_thread mt ON ss.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.ts < ${event_end_ts}
    AND ss.ts + ss.dur > ${event_ts}
  GROUP BY ss.cpu
)
SELECT
  'MainThread' as thread_type,
  ROUND(SUM(CASE WHEN core_type IN ('prime', 'big') THEN dur_ms ELSE 0 END), 2) as big_core_ms,
  ROUND(SUM(CASE WHEN core_type IN ('medium', 'little') THEN dur_ms ELSE 0 END), 2) as little_core_ms,
  ROUND(SUM(dur_ms), 2) as total_running_ms,
  ROUND(100.0 * SUM(CASE WHEN core_type IN ('prime', 'big') THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as big_core_pct,
  ROUND(100.0 * SUM(CASE WHEN core_type IN ('medium', 'little') THEN dur_ms ELSE 0 END) /
        NULLIF(SUM(dur_ms), 0), 1) as little_core_pct,
  ROUND(100.0 * SUM(dur_ms) / ${total_ms}, 1) as running_pct,
  GROUP_CONCAT(DISTINCT cpu) as used_cpus,
  (SELECT classify_method FROM topology_meta) as classify_method
FROM cpu_time
GROUP BY 1
