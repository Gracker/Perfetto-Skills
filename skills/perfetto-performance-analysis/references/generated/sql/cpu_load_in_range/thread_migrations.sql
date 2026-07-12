-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_load_in_range.skill.yaml
-- Source SHA-256: 71e2b4436e6f0eb4a11f04bf71bfc3a9703ee7c738fb37d8ddf20f67ec7bc955
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
migrations AS (
  SELECT
    utid,
    cpu,
    LAG(cpu) OVER (PARTITION BY utid ORDER BY ts) as prev_cpu
  FROM sched_slice
  WHERE (ts + dur) > ${start_ts}
    AND ts < ${end_ts}
)
SELECT
  COUNT(*) as migration_count,
  SUM(CASE
    WHEN (prev_cpu IN (SELECT cpu_id FROM _cpu_topology WHERE core_type IN ('medium', 'little'))
          AND cpu IN (SELECT cpu_id FROM _cpu_topology WHERE core_type IN ('prime', 'big')))
         OR (prev_cpu IN (SELECT cpu_id FROM _cpu_topology WHERE core_type IN ('prime', 'big'))
             AND cpu IN (SELECT cpu_id FROM _cpu_topology WHERE core_type IN ('medium', 'little')))
    THEN 1 ELSE 0
  END) as cross_cluster_migrations
FROM migrations
WHERE prev_cpu IS NOT NULL AND cpu != prev_cpu
