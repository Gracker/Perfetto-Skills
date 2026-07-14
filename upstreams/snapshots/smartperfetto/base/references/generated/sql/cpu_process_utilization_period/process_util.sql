-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
-- Source SHA-256: a37173b25f5c40b5fdbe2f46e13e980b8eca451f7e52275826547e3480585ea2
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH target_processes AS (
  SELECT upid, name AS process_name
  FROM process
  WHERE upid IS NOT NULL AND name IS NOT NULL
), samples AS (
  SELECT
    p.process_name,
    u.ts,
    u.utilization
  FROM target_processes p
  CROSS JOIN cpu_process_utilization_per_period(time_from_ms(100), p.upid) u
)
SELECT process_name, ts, ROUND(utilization, 4) AS utilization
FROM samples
ORDER BY utilization DESC
LIMIT 30
