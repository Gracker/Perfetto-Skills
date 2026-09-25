-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_thread_utilization_period.skill.yaml
-- Source SHA-256: 33bc2d55f1090e9b8c58eff082eee8ef1ef9f3fe47d0299431a9fb1057af264b
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH target_threads AS (
  SELECT t.utid, t.name AS thread_name, p.name AS process_name
  FROM thread t
  LEFT JOIN process p USING (upid)
  WHERE t.utid IS NOT NULL
    AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
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
