-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 01c95791e727e794914309ad6d43a4c1031919d195ae01d52f20ce5420d70576
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  name as irq_name,
  COUNT(*) AS irq_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(dur) / 1e3, 2) AS avg_dur_us,
  ROUND(MAX(dur) / 1e3, 2) AS max_dur_us,
  CASE
    WHEN MAX(dur) / 1e3 > ${hard_irq_long_threshold_us|1000} * 5 THEN 'critical'
    WHEN MAX(dur) / 1e3 > ${hard_irq_long_threshold_us|1000} THEN 'warning'
    WHEN MAX(dur) / 1e3 > ${hard_irq_long_threshold_us|1000} / 10 THEN 'notice'
    ELSE 'normal'
  END as severity
FROM slice
WHERE (name LIKE 'irq/%' OR name LIKE 'irq_handler_%')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY name
ORDER BY total_dur_ms DESC
LIMIT 20
