-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_thread_utilization_period.skill.yaml
-- Source SHA-256: 44ae1627a2ce3cfe119c52b3ba5f960828012d37c7afe1688dbe547eb2419d67
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

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
  WHERE (${start_ts} IS NULL OR u.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR u.ts < ${end_ts})
)
SELECT process_name, thread_name, ts, ROUND(utilization, 4) AS utilization
FROM samples
ORDER BY utilization DESC
LIMIT ${top_n|30}
