-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/battery_doze_state_timeline.skill.yaml
-- Source SHA-256: 38c6fc6d472d705aaa1f872ee022272227ec52cff40e8269d1c1f0f44b2cc021

WITH
states AS (
  SELECT 'deep' AS state_machine, ts, dur, deep_idle_state AS state FROM android_deep_idle_state
  UNION ALL
  SELECT 'light' AS state_machine, ts, dur, light_idle_state AS state FROM android_light_idle_state
),
ranked AS (
  SELECT
    state_machine,
    ts,
    dur,
    state,
    ROW_NUMBER() OVER (PARTITION BY state_machine ORDER BY ts ASC) AS rn_first,
    ROW_NUMBER() OVER (PARTITION BY state_machine ORDER BY ts DESC) AS rn_last,
    CASE
      WHEN (${start_ts} IS NULL OR ts + dur > ${start_ts})
        AND (${end_ts} IS NULL OR ts < ${end_ts}) THEN 1
      ELSE 0
    END AS in_window
  FROM states
)
SELECT
  state_machine,
  COUNT(*) AS trace_intervals,
  SUM(in_window) AS window_intervals,
  COUNT(*) - SUM(in_window) AS outside_window_intervals,
  SUM(CASE WHEN state = 'idle' THEN 1 ELSE 0 END) AS idle_entries,
  MIN(CASE WHEN state = 'idle' THEN ts END) AS first_idle_ts,
  ROUND(SUM(CASE WHEN state = 'idle' THEN dur ELSE 0 END) / 1e9, 3) AS idle_total_s,
  ROUND(MIN(CASE WHEN rn_last > 1 THEN dur END) / 1e6, 3) AS min_dwell_ms,
  GROUP_CONCAT(CASE WHEN rn_first <= 24 THEN state END, '>' ORDER BY ts) AS state_sequence,
  MAX(CASE WHEN rn_last = 1 THEN state END) AS last_state
FROM ranked
GROUP BY state_machine
ORDER BY state_machine
