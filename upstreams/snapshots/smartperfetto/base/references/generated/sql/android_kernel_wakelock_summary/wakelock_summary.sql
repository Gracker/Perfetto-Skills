-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_kernel_wakelock_summary.skill.yaml
-- Source SHA-256: 460ab6fbd3f45ed72d7f8492cd2f73ce2d0205a7d72326f470b52d22b6c54ff0
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH window_bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS win_start,
    COALESCE(${end_ts}, trace_end()) AS win_end,
    COALESCE(${end_ts}, trace_end()) - COALESCE(${start_ts}, trace_start()) AS observed_window_ns
),
clipped AS (
  SELECT
    name,
    type,
    wb.observed_window_ns,
    CASE
      WHEN dur > 0 THEN held_dur * (
        MIN(ts + dur, wb.win_end) -
        MAX(ts, wb.win_start)
      ) / dur
      ELSE held_dur
    END AS clipped_held_dur,
    CASE
      WHEN dur > 0 THEN awake_dur * (
        MIN(ts + dur, wb.win_end) -
        MAX(ts, wb.win_start)
      ) / dur
      ELSE awake_dur
    END AS clipped_awake_dur
  FROM android_kernel_wakelocks
  CROSS JOIN window_bounds wb
  WHERE ts < wb.win_end
    AND ts + dur > wb.win_start
)
SELECT
  name,
  ROUND(SUM(clipped_held_dur) / 1e9, 1) AS total_held_sec,
  COUNT(*) AS count,
  ROUND(SUM(clipped_held_dur) * 100.0 / NULLIF(SUM(clipped_awake_dur), 0), 2) AS held_ratio_pct,
  ROUND(MAX(observed_window_ns) / 3600000000000.0, 2) AS observed_window_hours,
  CASE
    WHEN MAX(observed_window_ns) >= 86400000000000 THEN 'full_24h_or_longer_window'
    ELSE 'partial_trace_window'
  END AS evidence_scope,
  CASE
    WHEN MAX(observed_window_ns) >= 86400000000000
         AND SUM(clipped_held_dur) >= 7200000000000 THEN 'excessive_24h_reference'
    WHEN SUM(clipped_held_dur) >= 3600000000000 THEN 'stuck_candidate_local_window'
    WHEN MAX(observed_window_ns) < 86400000000000 THEN 'partial_window_not_vitals_judgment'
    ELSE 'below_local_reference'
  END AS vitals_hint
FROM clipped
GROUP BY name
ORDER BY total_held_sec DESC
LIMIT 30
