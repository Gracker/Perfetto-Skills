-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/modules/hardware/cpu_module.skill.yaml
-- Source SHA-256: d035f125f1bd29ac6f675796781f4037254da8283f6dc51f661b1b9e5afaa51e
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

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
