-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH irq_stats AS (
  SELECT
    name as irq_name,
    CASE WHEN is_soft_irq = 1 THEN 'Soft IRQ' ELSE 'Hard IRQ' END as irq_type,
    COUNT(*) as irq_count,
    SUM(dur) as total_dur_ns,
    AVG(dur) as avg_dur_ns,
    MAX(dur) as max_dur_ns
  FROM linux_irqs
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
  GROUP BY name
),
total AS (
  SELECT SUM(total_dur_ns) as all_dur_ns FROM irq_stats
)
SELECT
  s.irq_name,
  s.irq_type,
  s.irq_count,
  ROUND(s.total_dur_ns / 1e6, 2) as total_dur_ms,
  ROUND(s.avg_dur_ns / 1e3, 2) as avg_dur_us,
  ROUND(s.max_dur_ns / 1e3, 2) as max_dur_us,
  ROUND(s.total_dur_ns * 100.0 / NULLIF((SELECT all_dur_ns FROM total), 0), 1) as time_pct
FROM irq_stats s
ORDER BY s.total_dur_ns DESC
LIMIT 20
