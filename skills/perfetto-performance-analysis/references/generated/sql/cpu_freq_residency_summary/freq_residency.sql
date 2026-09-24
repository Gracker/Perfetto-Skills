-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_freq_residency_summary.skill.yaml
-- Source SHA-256: 551f4b3dae5db3b84e15a017225eeb4399a0a9824fe59a04fbf47a30395103d5
-- Source commit: e7ff73a937cc66d89fdc69d59728025734759acd

WITH params AS (
  SELECT COALESCE(${start_ts}, trace_start()) AS start_ts,
    COALESCE(${end_ts}, trace_end()) AS end_ts
), clipped AS (
  SELECT
    f.ucpu,
    f.freq,
    MIN(f.ts + f.dur, p.end_ts) - MAX(f.ts, p.start_ts) AS clipped_dur
  FROM cpu_frequency_counters f
  CROSS JOIN params p
  WHERE f.ts < p.end_ts AND f.ts + f.dur > p.start_ts
    AND f.dur > 0 AND f.freq >= 0 AND p.end_ts > p.start_ts
), cpu_max AS (
  SELECT ucpu, MAX(freq) AS max_freq
  FROM clipped
  GROUP BY ucpu
), cpu_residency AS (
  SELECT c.ucpu, SUM(clipped_dur) AS known_dur,
    SUM(CASE WHEN freq >= max_freq * 0.8 THEN clipped_dur ELSE 0 END) AS high_dur,
    SUM(freq * 1.0 * clipped_dur) AS weighted_freq,
    MAX(max_freq) AS max_freq
  FROM clipped c JOIN cpu_max USING (ucpu)
  GROUP BY c.ucpu
), censored AS (
  SELECT f.ucpu, COUNT(*) AS interval_count
  FROM cpu_frequency_counters f CROSS JOIN params p
  WHERE f.dur < 0 AND f.ts < p.end_ts AND p.end_ts > p.start_ts
  GROUP BY f.ucpu
)
SELECT
  cpu.machine_id,
  COALESCE(m.cluster_type, 'unknown') AS cluster_type,
  COUNT(*) AS cpu_count,
  ROUND(SUM(r.known_dur) / 1e9, 2) AS total_residency_sec,
  ROUND(SUM(r.high_dur) / 1e9, 2) AS high_freq_residency_sec,
  ROUND(SUM(r.high_dur) * 100.0 / NULLIF(SUM(r.known_dur), 0), 2) AS high_freq_ratio_pct,
  ROUND(SUM(r.weighted_freq) / NULLIF(SUM(r.known_dur), 0) / 1000.0, 0) AS weighted_avg_freq_mhz,
  ROUND(MAX(r.max_freq) / 1000.0, 0) AS max_freq_mhz,
  ROUND(COALESCE(SUM(r.known_dur), 0) * 100.0 /
    NULLIF(COUNT(*) * (p.end_ts - p.start_ts), 0), 2) AS frequency_coverage_pct,
  CASE WHEN SUM(r.known_dur) IS NULL THEN 'missing'
    WHEN SUM(r.known_dur) = COUNT(*) * (p.end_ts - p.start_ts) THEN 'complete'
    WHEN SUM(r.known_dur) > COUNT(*) * (p.end_ts - p.start_ts) THEN 'overlapping_intervals'
    ELSE 'partial' END AS frequency_coverage_status,
  COALESCE(SUM(c.interval_count), 0) AS censored_interval_count,
  '80_percent_of_each_cpu_window_observed_peak_not_hardware_limit' AS high_frequency_basis
FROM cpu CROSS JOIN params p
LEFT JOIN android_cpu_cluster_mapping m ON m.ucpu = cpu.ucpu
LEFT JOIN cpu_residency r ON r.ucpu = cpu.ucpu
LEFT JOIN censored c ON c.ucpu = cpu.ucpu
WHERE p.end_ts > p.start_ts
GROUP BY cpu.machine_id, COALESCE(m.cluster_type, 'unknown')
ORDER BY high_freq_ratio_pct DESC
