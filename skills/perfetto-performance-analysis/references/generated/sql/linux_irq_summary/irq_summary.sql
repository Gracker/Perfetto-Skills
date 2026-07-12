-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_irq_summary.skill.yaml
-- Source SHA-256: 5ed6c6bb88f94df602ca5a751e53d30bec9514dcbff8bb6ece838bfcb963369d
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  name,
  COUNT(*) AS count,
  ROUND(SUM(dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(dur) / 1e3, 1) AS avg_dur_us
FROM (
  SELECT linux_hard_irqs.name AS name, linux_hard_irqs.dur AS dur FROM linux_hard_irqs
  UNION ALL
  SELECT linux_soft_irqs.name AS name, linux_soft_irqs.dur AS dur FROM linux_soft_irqs
)
GROUP BY name
ORDER BY total_dur_ms DESC
LIMIT 30
