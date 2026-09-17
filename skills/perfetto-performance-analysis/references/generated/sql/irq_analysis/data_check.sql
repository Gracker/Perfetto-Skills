-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: f009fd41aa9f0a562da268c17227701662484f515d5399de8137df35dc9cf21d
-- Source commit: e198ac39082cf1b029b0833e46e8ee49dd9387ce

SELECT
  CASE WHEN EXISTS (SELECT 1 FROM linux_irqs) THEN 1 ELSE 0 END as has_irq_data
