-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/thermal_predictor.skill.yaml
-- Source SHA-256: 16bb6ec7bc5e0769d25f1b2b46ed3a8d7d71648c6c6ae67e745ef86966aaa7ef
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH freq_samples AS (
  SELECT
    t.cpu,
    c.ts,
    c.value / 1000.0 as freq_mhz
  FROM counter c
  JOIN cpu_counter_track t ON c.track_id = t.id
  WHERE t.name = 'cpufreq'
    AND c.ts >= ${start_ts}
    AND c.ts < ${end_ts}
),
ordered AS (
  SELECT
    *,
    PERCENT_RANK() OVER (PARTITION BY cpu ORDER BY ts) as ts_rank
  FROM freq_samples
),
per_cpu AS (
  SELECT
    cpu,
    AVG(CASE WHEN ts_rank <= 0.2 THEN freq_mhz END) as start_freq_mhz,
    AVG(CASE WHEN ts_rank >= 0.8 THEN freq_mhz END) as end_freq_mhz,
    MAX(freq_mhz) as max_freq_mhz,
    MIN(freq_mhz) as min_freq_mhz
  FROM ordered
  GROUP BY cpu
),
scored AS (
  SELECT
    cpu,
    start_freq_mhz,
    end_freq_mhz,
    max_freq_mhz,
    min_freq_mhz,
    CASE
      WHEN start_freq_mhz IS NULL OR start_freq_mhz <= 0 THEN NULL
      ELSE 100.0 * (start_freq_mhz - end_freq_mhz) / start_freq_mhz
    END as drop_pct,
    CASE
      WHEN min_freq_mhz < max_freq_mhz * (1 - ${core_drop_threshold_pct|30} / 100.0) THEN 1 ELSE 0
    END as likely_throttled
  FROM per_cpu
)
SELECT
  ROUND(AVG(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN start_freq_mhz END), 0) as avg_start_freq_mhz,
  ROUND(AVG(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN end_freq_mhz END), 0) as avg_end_freq_mhz,
  ROUND(AVG(drop_pct), 1) as avg_drop_pct,
  ROUND(
    100.0 * SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN likely_throttled ELSE 0 END)
    / NULLIF(SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN 1 ELSE 0 END), 0),
    1
  ) as throttled_core_ratio_pct,
  CASE
    WHEN AVG(drop_pct) >= ${high_drop_threshold_pct|30}
         OR (
           100.0 * SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN likely_throttled ELSE 0 END)
           / NULLIF(SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN 1 ELSE 0 END), 0)
         ) >= ${high_core_ratio_threshold_pct|50}
      THEN 'high'
    WHEN AVG(drop_pct) >= ${medium_drop_threshold_pct|15}
         OR (
           100.0 * SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN likely_throttled ELSE 0 END)
           / NULLIF(SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN 1 ELSE 0 END), 0)
         ) >= ${medium_core_ratio_threshold_pct|25}
      THEN 'medium'
    ELSE 'low'
  END as thermal_risk,
  CASE
    WHEN AVG(drop_pct) >= ${high_drop_threshold_pct|30}
         OR (
           100.0 * SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN likely_throttled ELSE 0 END)
           / NULLIF(SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN 1 ELSE 0 END), 0)
         ) >= ${high_core_ratio_threshold_pct|50}
      THEN '频率持续下探，预计短时间内出现热限频，建议降载或分批执行重任务'
    WHEN AVG(drop_pct) >= ${medium_drop_threshold_pct|15}
         OR (
           100.0 * SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN likely_throttled ELSE 0 END)
           / NULLIF(SUM(CASE WHEN start_freq_mhz IS NOT NULL AND start_freq_mhz > 0 THEN 1 ELSE 0 END), 0)
         ) >= ${medium_core_ratio_threshold_pct|25}
      THEN '存在热压趋势，建议观察后续频率恢复与帧稳定性'
    ELSE '当前热控风险较低'
  END as prediction
FROM scored
