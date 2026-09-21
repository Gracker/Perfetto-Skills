-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/startup_freq_rampup.skill.yaml
-- Source SHA-256: 6f5c949fb38180d0c6f2fb90172a4357d8a192a449da1c88d7bfe8ebade4a876
-- Source commit: bc007586871a720aed82537913617c64fb95a459

-- Observed frequency is not hardware capacity, a governor request or proof of delay.
WITH phases AS (
  SELECT 'early' AS phase, ${start_ts} AS start_ts,
    MIN(${end_ts}, ${start_ts} + 100000000) AS end_ts
  UNION ALL
  SELECT 'steady', MIN(${end_ts}, ${start_ts} + 100000000), ${end_ts}
), spans AS (
  SELECT ucpu, ts, CASE WHEN dur = -1 THEN trace_end() ELSE ts + dur END AS end_ts, freq
  FROM cpu_frequency_counters
  WHERE (dur > 0 OR dur = -1) AND freq IS NOT NULL AND freq >= 0
), clipped AS (
  SELECT c.ucpu, c.cpu, c.machine_id, p.phase,
    p.end_ts - p.start_ts AS window_ns,
    MAX(f.ts, p.start_ts) AS clipped_start,
    MIN(f.end_ts, p.end_ts) AS clipped_end,
    f.freq
  FROM cpu c CROSS JOIN phases p
  LEFT JOIN spans f ON f.ucpu = c.ucpu AND f.ts < p.end_ts
    AND f.end_ts > p.start_ts AND p.end_ts > p.start_ts
), overlap_check AS (
  SELECT *, MAX(clipped_end) OVER (PARTITION BY ucpu, phase ORDER BY clipped_start, clipped_end
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prior_end
  FROM clipped
), measured AS (
  SELECT ucpu, cpu, machine_id, phase, window_ns,
    COALESCE(SUM(clipped_end - clipped_start), 0) AS covered_ns,
    MAX(CASE WHEN prior_end > clipped_start THEN 1 ELSE 0 END) AS overlap_conflict,
    SUM(freq * (clipped_end - clipped_start)) /
      NULLIF(SUM(clipped_end - clipped_start), 0) / 1000.0 AS avg_freq_mhz,
    MAX(freq) / 1000.0 AS observed_max_mhz
  FROM overlap_check GROUP BY ucpu, cpu, machine_id, phase, window_ns
), per_cpu AS (
  SELECT e.ucpu, e.cpu, e.machine_id,
    CASE WHEN e.overlap_conflict = 0 THEN e.avg_freq_mhz END AS early_avg_freq_mhz,
    CASE WHEN s.overlap_conflict = 0 THEN s.avg_freq_mhz END AS steady_avg_freq_mhz,
    CASE WHEN e.observed_max_mhz IS NULL THEN s.observed_max_mhz
      WHEN s.observed_max_mhz IS NULL THEN e.observed_max_mhz
      ELSE MAX(e.observed_max_mhz, s.observed_max_mhz) END AS max_freq_mhz,
    e.covered_ns AS early_covered_ns, e.window_ns AS early_window_ns,
    s.covered_ns AS steady_covered_ns, s.window_ns AS steady_window_ns,
    CASE WHEN e.overlap_conflict > 0 OR s.overlap_conflict > 0 THEN 'overlapping_frequency_spans'
      WHEN e.window_ns <= 0 OR s.window_ns <= 0 THEN 'no_comparison_window'
      WHEN e.covered_ns < e.window_ns OR s.covered_ns < s.window_ns THEN 'insufficient_frequency_coverage'
      WHEN s.avg_freq_mhz > e.avg_freq_mhz THEN 'later_frequency_higher_observed'
      ELSE 'later_frequency_not_higher_observed' END AS assessment
  FROM measured e JOIN measured s ON e.ucpu = s.ucpu AND s.phase = 'steady'
  WHERE e.phase = 'early'
)
SELECT *, CASE WHEN assessment IN ('later_frequency_higher_observed', 'later_frequency_not_higher_observed')
    THEN (steady_avg_freq_mhz - early_avg_freq_mhz) / NULLIF(early_avg_freq_mhz, 0) * 100.0 END AS rampup_pct,
  'frequency_comparison_only_not_capacity_throttling_or_governor_delay_proof' AS claim_boundary
FROM per_cpu ORDER BY ucpu
