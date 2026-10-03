-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: fea29723032ba827d7c7b294e22ea8ff4633c9c6e8abb832895f9a9642a6e595

SELECT
  CASE WHEN EXISTS (SELECT 1 FROM linux_irqs) THEN 1 ELSE 0 END as has_irq_data
