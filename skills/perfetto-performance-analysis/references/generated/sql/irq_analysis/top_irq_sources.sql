-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 01c95791e727e794914309ad6d43a4c1031919d195ae01d52f20ce5420d70576
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH irq_stats AS (
  SELECT
    name as irq_name,
    CASE
      WHEN name LIKE 'irq/%' OR name LIKE 'irq_handler_%' THEN 'Hard IRQ'
      ELSE 'Soft IRQ'
    END as irq_type,
    COUNT(*) as irq_count,
    SUM(dur) as total_dur_ns,
    AVG(dur) as avg_dur_ns,
    MAX(dur) as max_dur_ns
  FROM slice
  WHERE (name LIKE 'irq/%' OR name LIKE 'softirq/%'
         OR name LIKE 'irq_handler_%' OR name LIKE 'softirq_%')
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
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
