-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_freq_rampup.skill.yaml
-- Source SHA-256: 5fdc44a881eba8aac3be4fc8cc7f6175bd41bc13c9a6fc164f19ec3b4bda8f28
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

-- Early phase: first 100ms of startup
WITH early_freq AS (
  SELECT
    COALESCE(ct.core_type, 'unknown') as core_type,
    ROUND(SUM(c.value * cf.dur) / NULLIF(SUM(cf.dur), 0) / 1000, 0) as avg_freq_mhz,
    ROUND(MAX(c.value) / 1000, 0) as max_freq_mhz
  FROM cpu_frequency_counters cf
  JOIN counter c ON cf.id = c.id
  LEFT JOIN _cpu_topology ct ON cf.cpu = ct.cpu_id
  WHERE cf.ts >= ${start_ts}
    AND cf.ts < ${start_ts} + 100000000  -- first 100ms
  GROUP BY core_type
),
-- Steady phase: 100ms to end
steady_freq AS (
  SELECT
    COALESCE(ct.core_type, 'unknown') as core_type,
    ROUND(SUM(c.value * cf.dur) / NULLIF(SUM(cf.dur), 0) / 1000, 0) as avg_freq_mhz,
    ROUND(MAX(c.value) / 1000, 0) as max_freq_mhz
  FROM cpu_frequency_counters cf
  JOIN counter c ON cf.id = c.id
  LEFT JOIN _cpu_topology ct ON cf.cpu = ct.cpu_id
  WHERE cf.ts >= ${start_ts} + 100000000  -- after first 100ms
    AND cf.ts < ${end_ts}
  GROUP BY core_type
)
SELECT
  COALESCE(ef.core_type, sf.core_type) as core_type,
  COALESCE(ef.avg_freq_mhz, 0) as early_avg_freq_mhz,
  COALESCE(sf.avg_freq_mhz, 0) as steady_avg_freq_mhz,
  COALESCE(sf.max_freq_mhz, ef.max_freq_mhz, 0) as max_freq_mhz,
  ROUND((COALESCE(sf.avg_freq_mhz, 0) - COALESCE(ef.avg_freq_mhz, 0))
    / NULLIF(COALESCE(ef.avg_freq_mhz, 1), 0) * 100, 1) as rampup_pct,
  CASE
    WHEN COALESCE(ef.avg_freq_mhz, 0) < COALESCE(sf.avg_freq_mhz, 0) * 0.5
      THEN '⚠️ 启动初期频率显著偏低，升频延迟明显'
    WHEN COALESCE(ef.avg_freq_mhz, 0) < COALESCE(sf.avg_freq_mhz, 0) * 0.8
      THEN '启动初期频率偏低，有一定升频延迟'
    ELSE '频率爬升正常'
  END as assessment
FROM early_freq ef
FULL OUTER JOIN steady_freq sf ON ef.core_type = sf.core_type
ORDER BY
  CASE COALESCE(ef.core_type, sf.core_type)
    WHEN 'prime' THEN 0 WHEN 'big' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END
