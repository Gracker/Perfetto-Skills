-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thread_affinity_violation.skill.yaml
-- Source SHA-256: 8b1f713a09cd8c1f1725b590ab20764687be3783a8ff9004606bbd80927bfecb
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH target_threads AS (
  SELECT
    t.utid,
    t.name as thread_name,
    p.name as process_name,
    p.pid,
    t.tid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND (
      t.tid = p.pid
      OR t.name = 'RenderThread'
      OR t.name GLOB '*Hwui*'
    )
),
sched_runs AS (
  SELECT
    s.utid,
    s.ts,
    s.cpu,
    tt.thread_name,
    tt.process_name
  FROM sched s
  JOIN target_threads tt ON s.utid = tt.utid
  WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
),
annotated AS (
  SELECT
    *,
    CASE
      WHEN LAG(cpu) OVER (PARTITION BY utid ORDER BY ts) IS NULL THEN 0
      WHEN LAG(cpu) OVER (PARTITION BY utid ORDER BY ts) != cpu THEN 1
      ELSE 0
    END as migrated
  FROM sched_runs
)
SELECT
  process_name,
  thread_name,
  COUNT(*) as run_samples,
  COUNT(DISTINCT cpu) as distinct_cpus,
  SUM(migrated) as migration_count,
  ROUND(100.0 * SUM(migrated) / NULLIF(COUNT(*), 0), 1) as migration_ratio_pct,
  CASE
    WHEN 100.0 * SUM(migrated) / NULLIF(COUNT(*), 0) >= ${migration_ratio_threshold|25} THEN 1
    ELSE 0
  END as affinity_violation
FROM annotated
GROUP BY process_name, thread_name
ORDER BY migration_ratio_pct DESC
