-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/thermal_throttling.skill.yaml
-- Source SHA-256: da05d8739326315402aed126434265da76f5216ccd8cefbbfa0ee780bbfe9f6c
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

WITH
thermal_peak AS (
  SELECT
    MAX(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) as peak_temp_c,
    AVG(CASE WHEN c.value > 1000 THEN c.value / 1000.0 ELSE c.value END) as avg_temp_c
  FROM counter c
  JOIN counter_track ct ON c.track_id = ct.id
  WHERE (ct.name LIKE '%thermal%' OR ct.name LIKE '%temp%' OR ct.name LIKE '%tsens%')
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
cpu_freq_stats AS (
  SELECT
    cct.cpu as cpu_id,
    MIN(c.value / 1000.0) as min_freq_mhz,
    MAX(c.value / 1000.0) as max_freq_mhz
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  WHERE cct.name = 'cpufreq'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  GROUP BY cct.cpu
),
throttled_cpus AS (
  SELECT COUNT(*) as cnt
  FROM cpu_freq_stats
  WHERE min_freq_mhz < max_freq_mhz * 0.5
),
freq_drops AS (
  SELECT COUNT(*) as cnt
  FROM (
    SELECT
      cct.cpu,
      c.value / 1000.0 as freq_mhz,
      LAG(c.value / 1000.0) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as prev_freq
    FROM counter c
    JOIN cpu_counter_track cct ON c.track_id = cct.id
    WHERE cct.name = 'cpufreq'
      AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
      AND (${end_ts} IS NULL OR c.ts < ${end_ts})
  ) sub
  WHERE prev_freq IS NOT NULL AND freq_mhz < prev_freq * 0.7
)
SELECT
  CASE
    WHEN (SELECT cnt FROM throttled_cpus) > 4
         AND COALESCE((SELECT peak_temp_c FROM thermal_peak), 0) > 70
      THEN 'THERMAL_THROTTLING'
    WHEN COALESCE((SELECT peak_temp_c FROM thermal_peak), 0) > 60
         AND COALESCE((SELECT avg_temp_c FROM thermal_peak), 0) > 55
      THEN 'SUSTAINED_HIGH_TEMP'
    WHEN (SELECT cnt FROM freq_drops) > 20
         AND COALESCE((SELECT peak_temp_c FROM thermal_peak), 0) > 50
      THEN 'THERMAL_THROTTLING'
    WHEN (SELECT cnt FROM freq_drops) > 10
      THEN 'FREQ_INSTABILITY'
    ELSE 'THERMAL_NORMAL'
  END as classification,
  ROUND(COALESCE((SELECT peak_temp_c FROM thermal_peak), 0), 1) as peak_temp_c,
  (SELECT cnt FROM throttled_cpus) as throttled_cpu_count,
  (SELECT cnt FROM freq_drops) as severe_drop_count,
  CASE
    WHEN (SELECT cnt FROM throttled_cpus) > 4
         AND COALESCE((SELECT peak_temp_c FROM thermal_peak), 0) > 70
      THEN '多核严重降频，热节流显著影响性能，建议降低负载或优化散热'
    WHEN COALESCE((SELECT peak_temp_c FROM thermal_peak), 0) > 60
         AND COALESCE((SELECT avg_temp_c FROM thermal_peak), 0) > 55
      THEN '持续高温，存在热节流风险，建议减少后台任务和 CPU 密集操作'
    WHEN (SELECT cnt FROM freq_drops) > 20
      THEN '频繁触发热节流降频，建议添加冷却间隔或优化计算密度'
    WHEN (SELECT cnt FROM freq_drops) > 10
      THEN '频率不稳定，可能受温度影响，建议监控散热'
    ELSE '温度正常，无明显热节流'
  END as description
