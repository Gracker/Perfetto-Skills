-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

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
