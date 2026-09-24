-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_throttling_in_range.skill.yaml
-- Source SHA-256: 66ed6bab7c1a8f9703f90d803207fe45d9ff00e880e15bea97c75600f0568c39
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

WITH
-- 上一步的限频证据读一次，供下面的判定复用
limit_status AS (
  SELECT '${limit_evidence.data[0].evidence_status}' AS status,
    ${limit_evidence.data[0].deepest_depth_pct|0} AS depth_pct
),
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
  CASE WHEN MIN(min_freq) < MAX(max_freq) * 0.7 THEN 1 ELSE 0 END as frequency_variation_detected,
  -- Only the cpufreq policy limit track can turn this from unknown into
  -- a fact; an observed frequency span never can.
  CASE WHEN (SELECT status FROM limit_status) = 'freq_limit_observed' THEN 1
    WHEN (SELECT status FROM limit_status) = 'no_limit_episode_in_range' THEN 0
    ELSE NULL END as throttle_detected,
  CASE WHEN (SELECT status FROM limit_status) = 'freq_limit_observed'
    THEN 'freq_limit_observed' ELSE 'thermal_evidence_missing' END as evidence_status,
  CASE WHEN (SELECT status FROM limit_status) = 'freq_limit_observed'
    THEN '区间内观测到 cpufreq policy 上限被下调（最大深度 ' || (SELECT depth_pct FROM limit_status) || '%）：限频确实发生；触发方仍需用 cpu_frequency_limit_attribution 判定'
    ELSE '频率变化可能来自负载下降或空闲 DVFS；需直接限频证据与同窗口负载才能确定热控原因' END as interpretation
FROM per_cpu_stats
GROUP BY
  CASE
    WHEN core_type IN ('prime', 'big') THEN '大核'
    ELSE '小核'
  END
ORDER BY core_type DESC
