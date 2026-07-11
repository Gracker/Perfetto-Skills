-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 2790ff697fe7ae14da02b54deb78e2d1b46dd8d3cbebb27599a1e20f8ca5a2cf
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  CASE WHEN EXISTS (
    SELECT 1 FROM slice
    WHERE name LIKE 'irq/%' OR name LIKE 'softirq/%'
       OR name LIKE 'irq_handler_%' OR name LIKE 'softirq_'
  ) THEN 1 ELSE 0 END as has_irq_data
