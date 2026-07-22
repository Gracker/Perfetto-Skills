-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: d1aa0860a3371aeb91af3a7e07f864dba1a417a0e9e9d1e3d1387ef0bb02aec2
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH lmk_events AS (
  SELECT ts AS kill_ts, process_name, pid
  FROM android_lmk_events
  WHERE CASE WHEN '${package}' != ''
             THEN process_name GLOB '*${package}*'
             ELSE 1 END
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
restarts AS (
  SELECT
    le.process_name,
    le.kill_ts,
    MIN(p.start_ts) AS restart_ts
  FROM lmk_events le
  JOIN process p ON p.name GLOB le.process_name || '*'
  WHERE p.start_ts > le.kill_ts
  GROUP BY le.process_name, le.kill_ts
)
SELECT
  process_name,
  COUNT(*) AS restart_count,
  ROUND(AVG((restart_ts - kill_ts) / 1e6), 2) AS avg_restart_delay_ms
FROM restarts
GROUP BY process_name
ORDER BY restart_count DESC
LIMIT 20
