-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: fea29723032ba827d7c7b294e22ea8ff4633c9c6e8abb832895f9a9642a6e595

WITH time_base AS (
  SELECT MIN(ts) as base_ts FROM linux_irqs
)
SELECT
  CAST((ts - (SELECT base_ts FROM time_base)) / 1e9 AS INT) AS second,
  SUM(CASE WHEN is_soft_irq = 0 THEN 1 ELSE 0 END) AS hard_irq_count,
  SUM(CASE WHEN is_soft_irq = 1 THEN 1 ELSE 0 END) AS soft_irq_count,
  ROUND(SUM(CASE WHEN is_soft_irq = 0 THEN dur ELSE 0 END) / 1e6, 2) AS hard_irq_dur_ms,
  ROUND(SUM(CASE WHEN is_soft_irq = 1 THEN dur ELSE 0 END) / 1e6, 2) AS soft_irq_dur_ms,
  COUNT(*) as total_irq_count
FROM linux_irqs
WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY second
ORDER BY second
LIMIT 120
