-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: 55ba35f956b88823c9a3ffe665eaf555f382cf899a866b669ae5a7011ec4c639
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
