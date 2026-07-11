-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 2790ff697fe7ae14da02b54deb78e2d1b46dd8d3cbebb27599a1e20f8ca5a2cf
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  CASE
    WHEN name LIKE 'irq/%' OR name LIKE 'irq_handler_%' THEN 'Hard IRQ'
    WHEN name LIKE 'softirq/%' OR name LIKE 'softirq_%' THEN 'Soft IRQ'
    ELSE 'Unknown'
  END AS irq_type,
  COUNT(*) AS irq_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(dur) / 1e3, 2) AS avg_dur_us,
  ROUND(MAX(dur) / 1e3, 2) AS max_dur_us
FROM slice
WHERE (name LIKE 'irq/%' OR name LIKE 'softirq/%'
       OR name LIKE 'irq_handler_%' OR name LIKE 'softirq_%')
  AND (${start_ts} IS NULL OR ts >= ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY irq_type
ORDER BY total_dur_ms DESC
