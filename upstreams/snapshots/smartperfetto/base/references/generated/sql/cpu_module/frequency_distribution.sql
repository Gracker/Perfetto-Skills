-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: 4a9d6de50b0314b731792232ca2a3ac602c68e7c870a4e4a3d95f97d9f84a688

WITH
cpu_info AS (
  SELECT cpu_id as cpu, core_type as cluster
  FROM _cpu_topology
),
freq_samples AS (
  SELECT
    cct.cpu as cpu,
    COALESCE(ci.cluster, 'unknown') AS cluster,
    c.ts as ts,
    c.value as freq_khz,
    LEAD(c.ts) OVER (PARTITION BY cct.cpu ORDER BY c.ts) as next_ts
  FROM counter c
  JOIN cpu_counter_track cct ON c.track_id = cct.id
  LEFT JOIN cpu_info ci ON cct.cpu = ci.cpu
  WHERE cct.name = 'cpufreq'
),
freq_intervals AS (
  SELECT
    cluster,
    CAST(freq_khz / 100000 AS INTEGER) * 100 AS freq_bucket_mhz,
    CASE
      WHEN next_ts IS NULL THEN 0
      WHEN next_ts > ts THEN next_ts - ts
      ELSE 0
    END as dur_ns
  FROM freq_samples
)
SELECT
  cluster,
  freq_bucket_mhz,
  COUNT(*) AS sample_count,
  CAST(SUM(dur_ns) / 1e9 AS REAL) AS time_sec
FROM freq_intervals
GROUP BY cluster, freq_bucket_mhz
ORDER BY cluster, freq_bucket_mhz
