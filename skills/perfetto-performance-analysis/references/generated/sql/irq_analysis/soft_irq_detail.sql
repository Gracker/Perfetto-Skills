-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  name as irq_name,
  COUNT(*) AS irq_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(dur) / 1e3, 2) AS avg_dur_us,
  ROUND(MAX(dur) / 1e3, 2) AS max_dur_us,
  CASE
    WHEN MAX(dur) / 1e3 > ${soft_irq_long_threshold_us|10000} * 5 THEN 'critical'
    WHEN MAX(dur) / 1e3 > ${soft_irq_long_threshold_us|10000} THEN 'warning'
    WHEN MAX(dur) / 1e3 > ${soft_irq_long_threshold_us|10000} / 10 THEN 'notice'
    ELSE 'normal'
  END as severity
FROM linux_irqs
WHERE is_soft_irq = 1
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY name
ORDER BY total_dur_ms DESC
LIMIT 20
