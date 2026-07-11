-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_throttling_in_range.skill.yaml
-- Source SHA-256: dfaad621766ab875e89c14795a27c2956c029bc84893cbabb175a44827fb001e
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH
-- 频率采样（带拓扑分类）
freq_samples AS (
  SELECT
    ct.core_type,
    t.cpu,
    c.ts,
    c.value / 1000.0 as freq_mhz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts} AND c.ts < ${end_ts}
),
-- 每个 CPU 的频率统计（用子查询获取首尾频率，避免 window + GROUP BY 问题）
per_cpu_stats AS (
  SELECT
    core_type,
    cpu,
    MIN(freq_mhz) as min_freq,
    MAX(freq_mhz) as max_freq,
    (SELECT fs2.freq_mhz FROM freq_samples fs2
     WHERE fs2.cpu = fs.cpu ORDER BY fs2.ts ASC LIMIT 1) as start_freq,
    (SELECT fs2.freq_mhz FROM freq_samples fs2
     WHERE fs2.cpu = fs.cpu ORDER BY fs2.ts DESC LIMIT 1) as end_freq
  FROM freq_samples fs
  GROUP BY core_type, cpu
)
-- 按核心类型聚合
SELECT
  CASE
    WHEN core_type IN ('prime', 'big') THEN '大核'
    ELSE '小核'
  END as core_type,
  ROUND(AVG(start_freq), 0) as start_freq_mhz,
  ROUND(AVG(end_freq), 0) as end_freq_mhz,
  ROUND(MIN(min_freq), 0) as min_freq_mhz,
  ROUND(MAX(max_freq), 0) as max_freq_mhz,
  ROUND(100.0 * (MAX(max_freq) - MIN(min_freq)) / NULLIF(MAX(max_freq), 0), 1) as freq_drop_pct,
  CASE WHEN MIN(min_freq) < MAX(max_freq) * 0.7 THEN 1 ELSE 0 END as throttle_detected
FROM per_cpu_stats
GROUP BY
  CASE
    WHEN core_type IN ('prime', 'big') THEN '大核'
    ELSE '小核'
  END
ORDER BY core_type DESC
