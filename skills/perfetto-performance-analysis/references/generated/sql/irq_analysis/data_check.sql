-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 01c95791e727e794914309ad6d43a4c1031919d195ae01d52f20ce5420d70576
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM slice
    WHERE name LIKE 'irq/%' OR name LIKE 'softirq/%'
       OR name LIKE 'irq_handler_%' OR name LIKE 'softirq_'
  ) THEN 1 ELSE 0 END as has_irq_data
