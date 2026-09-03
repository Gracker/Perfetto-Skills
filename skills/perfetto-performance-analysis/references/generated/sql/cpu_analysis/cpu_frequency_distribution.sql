-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: bbe145b95ab30fa9dd885a45be7807284558b2acb6ae49984bc6a0c137982397
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

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
