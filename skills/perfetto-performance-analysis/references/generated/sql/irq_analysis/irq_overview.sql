-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: fea29723032ba827d7c7b294e22ea8ff4633c9c6e8abb832895f9a9642a6e595

SELECT
  CASE WHEN is_soft_irq = 1 THEN 'Soft IRQ' ELSE 'Hard IRQ' END AS irq_type,
  COUNT(*) AS irq_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(dur) / 1e3, 2) AS avg_dur_us,
  ROUND(MAX(dur) / 1e3, 2) AS max_dur_us
FROM linux_irqs
WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY irq_type
ORDER BY total_dur_ms DESC
