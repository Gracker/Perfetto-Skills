-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_cpu_placement_timeline.skill.yaml
-- Source SHA-256: d69eb45820fa5548bf1eb21d16e03bfa005b5517174b1a476bcba1ea67dcc809
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${package}*' AND t.tid = p.pid
  LIMIT 1
),
-- Generate time buckets (max 30 buckets)
bucket_size AS (
  SELECT MAX(${bucket_ms|50} * 1000000, (${end_ts} - ${start_ts}) / 30) as bucket_ns
),
buckets AS (
  SELECT
    0 as bucket_idx,
    ${start_ts} as bucket_start,
    MIN(${start_ts} + (SELECT bucket_ns FROM bucket_size), ${end_ts}) as bucket_end
  UNION ALL
  SELECT
    bucket_idx + 1,
    bucket_end,
    MIN(bucket_end + (SELECT bucket_ns FROM bucket_size), ${end_ts})
  FROM buckets
  WHERE bucket_end < ${end_ts} AND bucket_idx < 29
),
-- Main thread sched data
main_sched AS (
  SELECT ss.ts, ss.dur, ss.cpu,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM sched_slice ss
  CROSS JOIN main_thread mt
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.utid = mt.utid
    AND ss.ts < ${end_ts} AND ss.ts + ss.dur > ${start_ts}
)
SELECT
  b.bucket_idx,
  ROUND((b.bucket_start - ${start_ts}) / 1e6, 0) as bucket_offset_ms,
  ROUND(COALESCE(SUM(CASE WHEN ms.core_type IN ('prime', 'big', 'medium')
    THEN (MIN(ms.ts + ms.dur, b.bucket_end) - MAX(ms.ts, b.bucket_start)) ELSE 0 END) / 1e6, 0), 2) as big_core_ms,
  ROUND(COALESCE(SUM(CASE WHEN ms.core_type = 'little'
    THEN (MIN(ms.ts + ms.dur, b.bucket_end) - MAX(ms.ts, b.bucket_start)) ELSE 0 END) / 1e6, 0), 2) as little_core_ms,
  ROUND(100.0 *
    COALESCE(SUM(CASE WHEN ms.core_type IN ('prime', 'big', 'medium')
      THEN (MIN(ms.ts + ms.dur, b.bucket_end) - MAX(ms.ts, b.bucket_start)) ELSE 0 END), 0) /
    NULLIF(
      COALESCE(SUM(MIN(ms.ts + ms.dur, b.bucket_end) - MAX(ms.ts, b.bucket_start)), 0), 0
    ), 1) as big_core_pct,
  GROUP_CONCAT(DISTINCT ms.cpu) as used_cpus,
  GROUP_CONCAT(DISTINCT ms.core_type) as core_types
FROM buckets b
LEFT JOIN main_sched ms ON ms.ts < b.bucket_end AND ms.ts + ms.dur > b.bucket_start
GROUP BY b.bucket_idx
ORDER BY b.bucket_idx
