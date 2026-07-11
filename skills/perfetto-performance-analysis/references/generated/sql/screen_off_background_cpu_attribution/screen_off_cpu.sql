-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/screen_off_background_cpu_attribution.skill.yaml
-- Source SHA-256: 30326a1331437f9fc5fba924c3b897a885ae7407962cab6d49007e66e9ffbb62
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH bounds AS (
  SELECT
    COALESCE(${start_ts}, trace_start()) AS start_ts,
    COALESCE(${end_ts}, trace_end()) AS end_ts
),
screen_off AS (
  SELECT
    MAX(s.ts, b.start_ts) AS ts,
    MIN(s.ts + s.dur, b.end_ts) AS ts_end,
    MIN(s.ts + s.dur, b.end_ts) - MAX(s.ts, b.start_ts) AS dur
  FROM android_screen_state s
  CROSS JOIN bounds b
  WHERE s.simple_screen_state IN ('off', 'doze')
    AND s.ts < b.end_ts
    AND s.ts + s.dur > b.start_ts
),
totals AS (
  SELECT SUM(dur) AS total_screen_off_dur
  FROM screen_off
  WHERE dur > 0
),
runtime AS (
  SELECT
    COALESCE(p.name, '') AS process_name,
    COALESCE(th.name, '') AS thread_name,
    SUM(MIN(s.ts + s.dur, o.ts_end) - MAX(s.ts, o.ts)) AS runtime_ns
  FROM screen_off o
  JOIN sched s
    ON s.ts < o.ts_end
    AND s.ts + s.dur > o.ts
  JOIN thread th USING (utid)
  LEFT JOIN process p USING (upid)
  WHERE o.dur > 0
    AND NOT th.is_idle
    AND (COALESCE(p.name, '') GLOB '${package}*' OR '${package}' = '')
  GROUP BY process_name, thread_name
),
cpu_count AS (
  SELECT COALESCE(MAX(cpu) + 1, 1) AS cpus
  FROM cpu
),
ranked AS (
  SELECT
    process_name,
    thread_name,
    ROUND((SELECT total_screen_off_dur FROM totals) / 1e9, 2) AS screen_off_time_sec,
    ROUND(runtime_ns / 1e6, 2) AS runtime_ms,
    ROUND(runtime_ns * 100.0 / NULLIF((SELECT total_screen_off_dur FROM totals) * (SELECT cpus FROM cpu_count), 0), 4) AS cpu_util_pct,
    'screen_state_sched_overlap' AS evidence_status
  FROM runtime
  WHERE runtime_ns > 0
  ORDER BY runtime_ns DESC
  LIMIT ${top_n|30}
)
SELECT * FROM ranked
UNION ALL
SELECT
  '' AS process_name,
  '' AS thread_name,
  ROUND(COALESCE((SELECT total_screen_off_dur FROM totals), 0) / 1e9, 2) AS screen_off_time_sec,
  0 AS runtime_ms,
  0 AS cpu_util_pct,
  CASE
    WHEN COALESCE((SELECT total_screen_off_dur FROM totals), 0) = 0 THEN 'no_screen_off_or_doze_window'
    ELSE 'no_background_cpu_runtime'
  END AS evidence_status
WHERE NOT EXISTS (SELECT 1 FROM ranked)
