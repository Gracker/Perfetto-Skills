-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

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
