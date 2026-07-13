-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/selection_range_cpu_sched_summary.skill.yaml
-- Source SHA-256: 31127ebb648421f06248c4ceb054d614d12df318c63b0a652a41f341b556310e
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
cpu_tracks AS (
  SELECT id, cpu
  FROM cpu_counter_track
  WHERE name = 'cpufreq' AND cpu IS NOT NULL
),
freq_points AS (
  SELECT
    t.cpu,
    ${start_ts} AS ts,
    (
      SELECT c2.value
      FROM counter c2
      WHERE c2.track_id = t.id AND c2.ts <= ${start_ts}
      ORDER BY c2.ts DESC
      LIMIT 1
    ) AS freq_khz,
    0 AS source_order
  FROM cpu_tracks t
  UNION ALL
  SELECT t.cpu, c.ts, c.value AS freq_khz, 1 AS source_order
  FROM counter c
  JOIN cpu_tracks t ON c.track_id = t.id
  WHERE c.ts >= ${start_ts} AND c.ts < ${end_ts}
),
freq_spans AS (
  SELECT
    cpu,
    freq_khz,
    ts,
    LEAD(ts, 1, ${end_ts}) OVER (PARTITION BY cpu ORDER BY ts, source_order) AS next_ts
  FROM freq_points
  WHERE freq_khz IS NOT NULL AND freq_khz > 0
),
clipped AS (
  SELECT
    cpu,
    CAST(ROUND(freq_khz / (${freq_bucket_mhz|100} * 1000.0)) * ${freq_bucket_mhz|100} AS INTEGER) AS freq_mhz_bucket,
    MIN(next_ts, ${end_ts}) - MAX(ts, ${start_ts}) AS dur_ns
  FROM freq_spans
  WHERE ts < ${end_ts} AND next_ts > ${start_ts}
)
SELECT
  c.cpu,
  COALESCE(ct.core_type, 'unknown') AS core_type,
  c.freq_mhz_bucket,
  ROUND(SUM(c.dur_ns) / 1e6, 2) AS duration_ms,
  ROUND(100.0 * SUM(c.dur_ns) / NULLIF(${end_ts} - ${start_ts}, 0), 1) AS pct_of_range
FROM clipped c
LEFT JOIN _cpu_topology ct ON c.cpu = ct.cpu_id
WHERE c.dur_ns > 0
GROUP BY c.cpu, c.freq_mhz_bucket
ORDER BY c.cpu, duration_ms DESC
LIMIT 100
