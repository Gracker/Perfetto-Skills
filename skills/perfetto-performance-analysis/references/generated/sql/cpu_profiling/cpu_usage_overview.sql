-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/deep/cpu_profiling.skill.yaml
-- Source SHA-256: a6a66506443dbaafa5b0ec8d01520c945065aa40ce65d0f89fd60577ae67e1ce
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

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
