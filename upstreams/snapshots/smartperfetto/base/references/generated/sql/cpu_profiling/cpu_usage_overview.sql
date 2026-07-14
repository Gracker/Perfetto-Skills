-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 747b9f8972708ad1e4c8449ab8e9876c58138f44ae4f3515d87232a9173a4772
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH
cpu_info AS (
  SELECT cpu_id, core_type, capacity
  FROM _cpu_topology
),
sched_stats AS (
  SELECT
    ss.cpu as cpu_id,
    SUM(ss.dur) / 1e6 as total_runtime_ms,
    COUNT(*) as slice_count
  FROM sched_slice ss
  GROUP BY ss.cpu
)
SELECT
  ci.core_type,
  COUNT(DISTINCT ci.cpu_id) as core_count,
  SUM(ss.total_runtime_ms) as total_runtime_ms,
  SUM(ss.slice_count) as total_slices,
  AVG(ci.capacity) as avg_capacity
FROM cpu_info ci
LEFT JOIN sched_stats ss ON ci.cpu_id = ss.cpu_id
GROUP BY ci.core_type
ORDER BY avg_capacity DESC
