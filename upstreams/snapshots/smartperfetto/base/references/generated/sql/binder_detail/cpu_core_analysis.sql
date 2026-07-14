-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: b21af48bb190aa382256c422c77267cce8f041f42257cbbd3a6f669e691f5bf9
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND t.tid = p.pid
),
cpu_time AS (
  SELECT
    ss.cpu,
    SUM(
      MIN(ss.ts + ss.dur, ${binder_end_ts}) - MAX(ss.ts, ${binder_ts})
    ) / 1e6 as dur_ms,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM sched_slice ss
  JOIN main_thread mt ON ss.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.ts < ${binder_end_ts}
    AND ss.ts + ss.dur > ${binder_ts}
  GROUP BY ss.cpu
)
SELECT
  'MainThread' as thread_type,
  ROUND(SUM(CASE WHEN core_type IN ('prime', 'big') THEN dur_ms ELSE 0 END), 2) as big_core_ms,
  ROUND(SUM(CASE WHEN core_type IN ('medium', 'little') THEN dur_ms ELSE 0 END), 2) as little_core_ms,
  ROUND(SUM(dur_ms), 2) as total_running_ms,
  ROUND(100.0 * SUM(dur_ms) / ${dur_ms}, 1) as running_pct
FROM cpu_time
GROUP BY 1
