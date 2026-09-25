-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_process_utilization_period.skill.yaml
-- Source SHA-256: 78a91e3d2a1f6e5640cfab917092a5c5463f08cb7051b7ab9d63f4f4e8258524
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH target_processes AS (
  SELECT upid, name AS process_name
  FROM process
  WHERE upid IS NOT NULL
    AND name IS NOT NULL
    AND ('${process_name}' = '' OR name = '${process_name}' OR name GLOB '${process_name}:*')
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
