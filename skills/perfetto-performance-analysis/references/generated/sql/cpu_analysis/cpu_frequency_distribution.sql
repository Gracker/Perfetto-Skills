-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  cf.cpu,
  ct.capacity,
  ct.core_type,
  cf.freq / 1000 as freq_mhz,
  SUM(cf.dur) / 1e6 as duration_ms,
  ROUND(100.0 * SUM(cf.dur) / (
    SELECT SUM(cf2.dur) FROM cpu_frequency_counters cf2
    WHERE cf2.cpu = cf.cpu
      AND (${start_ts} IS NULL OR cf2.ts + cf2.dur > ${start_ts})
      AND (${end_ts} IS NULL OR cf2.ts < ${end_ts})
  ), 1) as percent
FROM cpu_frequency_counters cf
JOIN _cpu_topology ct ON cf.cpu = ct.cpu_id
WHERE (${start_ts} IS NULL OR cf.ts + cf.dur > ${start_ts})
  AND (${end_ts} IS NULL OR cf.ts < ${end_ts})
GROUP BY cf.cpu, cf.freq
HAVING duration_ms > 10  -- 过滤太短的
ORDER BY cf.cpu, freq_mhz DESC
LIMIT 30
