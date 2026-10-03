-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/irq_analysis.skill.yaml
-- Source SHA-256: fea29723032ba827d7c7b294e22ea8ff4633c9c6e8abb832895f9a9642a6e595

SELECT
  printf('%d', li.ts) as ts,
  li.name as irq_name,
  CASE WHEN li.is_soft_irq = 1 THEN 'Soft IRQ' ELSE 'Hard IRQ' END AS irq_type,
  ROUND(li.dur / 1e3, 2) AS dur_us,
  extract_arg(t.dimension_arg_set_id, 'cpu') as cpu,
  CASE
    WHEN li.is_soft_irq = 0 THEN
      CASE
        WHEN li.dur / 1e3 > ${hard_irq_long_threshold_us|1000} * 5 THEN 'critical'
        WHEN li.dur / 1e3 > ${hard_irq_long_threshold_us|1000} THEN 'warning'
        ELSE 'notice'
      END
    ELSE
      CASE
        WHEN li.dur / 1e3 > ${soft_irq_long_threshold_us|10000} * 5 THEN 'critical'
        WHEN li.dur / 1e3 > ${soft_irq_long_threshold_us|10000} THEN 'warning'
        ELSE 'notice'
      END
  END as severity
FROM linux_irqs li
JOIN slice s ON s.id = li.id
JOIN track t ON t.id = s.track_id
WHERE (${start_ts} IS NULL OR li.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR li.ts < ${end_ts})
  -- 硬中断 > threshold 或 软中断 > threshold
  AND (
    (li.is_soft_irq = 0 AND li.dur > ${hard_irq_long_threshold_us|1000} * 1000)
    OR (li.is_soft_irq = 1 AND li.dur > ${soft_irq_long_threshold_us|10000} * 1000)
  )
ORDER BY li.dur DESC
LIMIT 30
