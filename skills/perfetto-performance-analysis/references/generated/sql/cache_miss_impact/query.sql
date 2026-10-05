-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cache_miss_impact.skill.yaml
-- Source SHA-256: a5e9c2ce0744ad86c74e38152e285cb285995961d91fb7b32c43d5f68844dad6

WITH raw AS (
  SELECT
    ct.name as counter_name,
    c.ts,
    c.value,
    c.value - LAG(c.value) OVER (PARTITION BY ct.id ORDER BY c.ts) as delta
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
    AND LOWER(ct.name) LIKE '%cache%'
    AND (
      LOWER(ct.name) LIKE '%miss%'
      OR LOWER(ct.name) LIKE '%mpki%'
    )
)
SELECT
  counter_name,
  COUNT(*) as samples,
  ROUND(SUM(CASE WHEN delta > 0 THEN delta ELSE 0 END), 0) as total_miss_delta,
  ROUND(AVG(CASE WHEN delta > 0 THEN delta END), 2) as avg_miss_delta,
  ROUND(MAX(CASE WHEN delta > 0 THEN delta END), 2) as peak_miss_delta,
  CASE
    WHEN AVG(CASE WHEN delta > 0 THEN delta END) >= ${high_impact_threshold|500000} THEN 'high'
    WHEN AVG(CASE WHEN delta > 0 THEN delta END) >= ${medium_impact_threshold|100000} THEN 'medium'
    ELSE 'low'
  END as impact_level
FROM raw
GROUP BY counter_name
ORDER BY avg_miss_delta DESC
