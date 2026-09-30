-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_throttling_in_range.skill.yaml
-- Source SHA-256: 05526dca03c6ffb8591b9ad7e6a6edd303221425e1e6e72589a289e0fd909505

WITH
-- 上一步的限频证据读一次，供下面的判定复用
limit_status AS (
  SELECT '${limit_evidence.data[0].evidence_status}' AS status,
    ${limit_evidence.data[0].deepest_depth_pct|0} AS depth_pct
),
-- 频率采样（带拓扑分类）；NULL 或 <= 0 不是频率，保留为 NULL。拓扑未收录的
-- CPU（如无 sched 时只有 0 值的核）也保留，归为 unknown
freq_samples AS (
  SELECT
    COALESCE(ct.core_type, 'unknown') AS core_type,
    t.id AS track_id,
    c.ts,
    CASE WHEN c.value > 0 THEN c.value / 1000.0 END AS freq_mhz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  LEFT JOIN _cpu_topology ct ON t.cpu = ct.cpu_id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts} AND c.ts < ${end_ts}
),
-- 每条 cpufreq 轨道的窗口内统计（子查询取首末有效采样，避免 window + GROUP BY 问题）
per_track_stats AS (
  SELECT
    core_type,
    track_id,
    MIN(freq_mhz) AS min_freq,
    MAX(freq_mhz) AS max_freq,
    (SELECT fs2.freq_mhz FROM freq_samples fs2
     WHERE fs2.track_id = fs.track_id AND fs2.freq_mhz IS NOT NULL
     ORDER BY fs2.ts ASC LIMIT 1) AS start_freq,
    (SELECT fs2.freq_mhz FROM freq_samples fs2
     WHERE fs2.track_id = fs.track_id AND fs2.freq_mhz IS NOT NULL
     ORDER BY fs2.ts DESC LIMIT 1) AS end_freq
  FROM freq_samples fs
  GROUP BY core_type, track_id
),
-- 按拓扑类别聚合；跨度只在单条轨道内算
per_tier_stats AS (
  SELECT
    CASE core_type
      WHEN 'prime' THEN '超大核'
      WHEN 'big' THEN '大核'
      WHEN 'medium' THEN '中核'
      WHEN 'little' THEN '小核'
      ELSE '未知'
    END AS tier_label,
    CASE core_type
      WHEN 'prime' THEN 1
      WHEN 'big' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'little' THEN 4
      ELSE 5
    END AS tier_rank,
    AVG(start_freq) AS start_freq,
    AVG(end_freq) AS end_freq,
    MIN(min_freq) AS min_freq,
    MAX(max_freq) AS max_freq,
    MAX(100.0 * (max_freq - min_freq) / max_freq) AS span_pct,
    -- 比较在无有效采样时为 NULL，MAX 忽略 NULL
    MAX(min_freq < max_freq * 0.7) AS span_over_threshold,
    COUNT(*) AS track_count,
    COUNT(max_freq) AS measured_track_count
  FROM per_track_stats
  GROUP BY core_type
)
SELECT
  tier_label AS core_type,
  ROUND(start_freq, 0) AS start_freq_mhz,
  ROUND(end_freq, 0) AS end_freq_mhz,
  ROUND(min_freq, 0) AS min_freq_mhz,
  ROUND(max_freq, 0) AS max_freq_mhz,
  ROUND(span_pct, 1) AS freq_drop_pct,
  span_over_threshold AS frequency_variation_detected,
  -- Only the cpufreq policy limit track can turn this from unknown into
  -- a fact; an observed frequency span never can.
  CASE status WHEN 'freq_limit_observed' THEN 1
    WHEN 'no_limit_episode_in_range' THEN 0 END AS throttle_detected,
  CASE WHEN status = 'freq_limit_observed'
    THEN 'freq_limit_observed' ELSE 'thermal_evidence_missing' END AS evidence_status,
  CASE WHEN tier_rank = 5
    THEN '核心类别未知：拓扑信息不足以可靠分级（如缺少完整 CPU capacity 元数据、单一均匀簇或多机器/元数据歧义），此行汇总这些核心的 cpufreq 轨道，不代表小核。'
    ELSE '' END ||
  CASE WHEN measured_track_count = 0 THEN '窗口内无有效频率采样，无法计算频率跨度。'
    WHEN measured_track_count < track_count THEN '部分 cpufreq 轨道窗口内无有效频率采样，跨度只覆盖有采样的轨道。'
    ELSE '' END ||
  CASE WHEN status = 'freq_limit_observed'
    THEN '区间内观测到 cpufreq policy 上限被下调（最大深度 ' || depth_pct || '%）：限频确实发生；这是整窗证据，不说明本行核心受限，触发方仍需用 cpu_frequency_limit_attribution 判定'
    ELSE '频率变化可能来自负载下降或空闲 DVFS；需直接限频证据与同窗口负载才能确定热控原因' END ||
  '（首末为各 cpufreq 轨道窗口内首末采样均值，非窗口边界值；最低/最高为本类别包络，可能来自不同核心）' AS interpretation
FROM per_tier_stats
CROSS JOIN limit_status
ORDER BY tier_rank
