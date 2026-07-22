-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_residency_summary.skill.yaml
-- Source SHA-256: 574b201a6ed4593061204a5cda42d112cb63665150c965bf038ba6a7a075daca
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH clipped AS (
  SELECT
    f.cpu,
    COALESCE(m.cluster_type, 'unknown') AS cluster_type,
    f.freq,
    MIN(f.ts + f.dur, COALESCE(${end_ts}, trace_end())) -
      MAX(f.ts, COALESCE(${start_ts}, trace_start())) AS clipped_dur
  FROM cpu_frequency_counters f
  LEFT JOIN android_cpu_cluster_mapping m USING (cpu)
  WHERE f.ts < COALESCE(${end_ts}, trace_end())
    AND f.ts + f.dur > COALESCE(${start_ts}, trace_start())
),
cpu_max AS (
  SELECT cpu, MAX(freq) AS max_freq
  FROM clipped
  WHERE clipped_dur > 0
  GROUP BY cpu
)
SELECT
  cluster_type,
  COUNT(DISTINCT cpu) AS cpu_count,
  ROUND(SUM(clipped_dur) / 1e9, 2) AS total_residency_sec,
  ROUND(SUM(CASE WHEN freq >= max_freq * 0.8 THEN clipped_dur ELSE 0 END) / 1e9, 2) AS high_freq_residency_sec,
  ROUND(SUM(CASE WHEN freq >= max_freq * 0.8 THEN clipped_dur ELSE 0 END) * 100.0 / NULLIF(SUM(clipped_dur), 0), 2) AS high_freq_ratio_pct,
  ROUND(SUM(freq * clipped_dur) / NULLIF(SUM(clipped_dur), 0) / 1000.0, 0) AS weighted_avg_freq_mhz,
  ROUND(MAX(max_freq) / 1000.0, 0) AS max_freq_mhz
FROM clipped
JOIN cpu_max USING (cpu)
WHERE clipped_dur > 0
GROUP BY cluster_type
ORDER BY high_freq_ratio_pct DESC
