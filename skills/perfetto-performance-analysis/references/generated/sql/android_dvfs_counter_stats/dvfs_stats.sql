-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_dvfs_counter_stats.skill.yaml
-- Source SHA-256: cf8599903da332db1aff2c03d179ffd4c5dd3ecd90fed3c66e1aafa3d74df84a
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH clipped AS (
  SELECT
    name,
    value,
    MIN(ts + dur, COALESCE(${end_ts}, trace_end())) -
      MAX(ts, COALESCE(${start_ts}, trace_start())) AS clipped_dur
  FROM android_dvfs_counters
  WHERE ts < COALESCE(${end_ts}, trace_end())
    AND ts + dur > COALESCE(${start_ts}, trace_start())
)
SELECT
  name,
  MIN(value) AS min,
  MAX(value) AS max,
  ROUND(SUM(value * clipped_dur) / NULLIF(SUM(clipped_dur), 0), 1) AS wgt_avg,
  ROUND(SUM(clipped_dur) / 1e9, 2) AS observed_sec
FROM clipped
WHERE clipped_dur > 0
GROUP BY name
ORDER BY name
