-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 2790ff697fe7ae14da02b54deb78e2d1b46dd8d3cbebb27599a1e20f8ca5a2cf
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH time_base AS (
  SELECT MIN(ts) as base_ts FROM slice
  WHERE name LIKE 'irq/%' OR name LIKE 'softirq/%'
        OR name LIKE 'irq_handler_%' OR name LIKE 'softirq_%'
)
SELECT
  CAST((s.ts - (SELECT base_ts FROM time_base)) / 1e9 AS INT) AS second,
  SUM(CASE WHEN s.name LIKE 'irq/%' OR s.name LIKE 'irq_handler_%'
           THEN 1 ELSE 0 END) AS hard_irq_count,
  SUM(CASE WHEN s.name LIKE 'softirq/%' OR s.name LIKE 'softirq_%'
           THEN 1 ELSE 0 END) AS soft_irq_count,
  ROUND(SUM(CASE WHEN s.name LIKE 'irq/%' OR s.name LIKE 'irq_handler_%'
                 THEN s.dur ELSE 0 END) / 1e6, 2) AS hard_irq_dur_ms,
  ROUND(SUM(CASE WHEN s.name LIKE 'softirq/%' OR s.name LIKE 'softirq_%'
                 THEN s.dur ELSE 0 END) / 1e6, 2) AS soft_irq_dur_ms,
  COUNT(*) as total_irq_count
FROM slice s
WHERE (s.name LIKE 'irq/%' OR s.name LIKE 'softirq/%'
       OR s.name LIKE 'irq_handler_%' OR s.name LIKE 'softirq_%')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
GROUP BY second
ORDER BY second
LIMIT 120
