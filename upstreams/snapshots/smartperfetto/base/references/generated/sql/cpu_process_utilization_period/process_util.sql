-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
-- Source SHA-256: 7ab91a94b9e4a6be4e1b8224e9e1b993140280825cff454d6124a73e98b00ec8
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH target_processes AS (
  SELECT upid, name AS process_name
  FROM process
  WHERE upid IS NOT NULL
    AND name IS NOT NULL
    AND (name GLOB '${process_name}*' OR '${process_name}' = '')
), samples AS (
  SELECT
    p.process_name,
    u.ts,
    u.utilization
  FROM target_processes p
  CROSS JOIN cpu_process_utilization_per_period(time_from_ms(100), p.upid) u
  WHERE (${start_ts} IS NULL OR u.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR u.ts < ${end_ts})
)
SELECT process_name, ts, ROUND(utilization, 4) AS utilization
FROM samples
ORDER BY utilization DESC
LIMIT 30
