-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: 2790ff697fe7ae14da02b54deb78e2d1b46dd8d3cbebb27599a1e20f8ca5a2cf
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  printf('%d', s.ts) as ts,
  s.name as irq_name,
  CASE
    WHEN s.name LIKE 'irq/%' OR s.name LIKE 'irq_handler_%' THEN 'Hard IRQ'
    ELSE 'Soft IRQ'
  END AS irq_type,
  ROUND(s.dur / 1e3, 2) AS dur_us,
  t.cpu as cpu,
  CASE
    WHEN s.name LIKE 'irq/%' OR s.name LIKE 'irq_handler_%' THEN
      CASE
        WHEN s.dur / 1e3 > ${hard_irq_long_threshold_us|1000} * 5 THEN 'critical'
        WHEN s.dur / 1e3 > ${hard_irq_long_threshold_us|1000} THEN 'warning'
        ELSE 'notice'
      END
    ELSE
      CASE
        WHEN s.dur / 1e3 > ${soft_irq_long_threshold_us|10000} * 5 THEN 'critical'
        WHEN s.dur / 1e3 > ${soft_irq_long_threshold_us|10000} THEN 'warning'
        ELSE 'notice'
      END
  END as severity
FROM slice s
LEFT JOIN thread_track tt ON s.track_id = tt.id
LEFT JOIN thread t ON tt.utid = t.utid
WHERE (s.name LIKE 'irq/%' OR s.name LIKE 'softirq/%'
       OR s.name LIKE 'irq_handler_%' OR s.name LIKE 'softirq_%')
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  -- 硬中断 > threshold 或 软中断 > threshold
  AND (
    ((s.name LIKE 'irq/%' OR s.name LIKE 'irq_handler_%') AND s.dur > ${hard_irq_long_threshold_us|1000} * 1000)
    OR ((s.name LIKE 'softirq/%' OR s.name LIKE 'softirq_%') AND s.dur > ${soft_irq_long_threshold_us|10000} * 1000)
  )
ORDER BY s.dur DESC
LIMIT 30
