-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_thread_utilization_period.skill.yaml
-- Source SHA-256: c8a23fe5e6ee9fe1e5138a2b5fa831ad15c09715f07fb81ca282c0f233074dec
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH target_threads AS (
  SELECT t.utid, t.name AS thread_name, p.name AS process_name
  FROM thread t
  LEFT JOIN process p USING (upid)
  WHERE t.utid IS NOT NULL
    AND (p.name GLOB '${process_name}*' OR '${process_name}' = '')
), samples AS (
  SELECT
    t.process_name,
    t.thread_name,
    u.ts,
    u.utilization
  FROM target_threads t
  CROSS JOIN cpu_thread_utilization_per_period(time_from_ms(100), t.utid) u
)
SELECT process_name, thread_name, ts, ROUND(utilization, 4) AS utilization
FROM samples
ORDER BY utilization DESC
LIMIT ${top_n|30}
