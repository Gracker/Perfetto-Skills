-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/cpu_idle_state_residency.skill.yaml
-- Source SHA-256: 7ca1a5633d514d72c2e841694bf0c3eb19be753350fdd1168e412761c8337eec
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH clipped AS (
  SELECT
    cpu,
    idle AS idle_state,
    MIN(ts + dur, COALESCE(${end_ts}, trace_end())) -
      MAX(ts, COALESCE(${start_ts}, trace_start())) AS clipped_dur
  FROM cpu_idle_counters
  WHERE ts < COALESCE(${end_ts}, trace_end())
    AND ts + dur > COALESCE(${start_ts}, trace_start())
),
totals AS (
  SELECT cpu, SUM(clipped_dur) AS total_dur
  FROM clipped
  WHERE clipped_dur > 0
  GROUP BY cpu
)
SELECT
  c.cpu,
  c.idle_state,
  ROUND(SUM(c.clipped_dur) / 1e6, 2) AS total_time_ms,
  ROUND(SUM(c.clipped_dur) * 100.0 / NULLIF(t.total_dur, 0), 2) AS residency_pct,
  COUNT(*) AS interval_count
FROM clipped c
JOIN totals t USING (cpu)
WHERE c.clipped_dur > 0
GROUP BY c.cpu, c.idle_state
ORDER BY c.cpu ASC, c.idle_state ASC
