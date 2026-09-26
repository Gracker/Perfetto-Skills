-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 380a21355baca5f8e2d2d740174e6f6897b0150f4d792c53f3b0d42de71a0f1b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

SELECT
  CAST(ts / 1e9 AS INTEGER) AS time_sec,
  COUNT(*) AS lmk_count,
  GROUP_CONCAT(process_name, ', ') AS killed_processes,
  ROUND(AVG(oom_score_adj), 0) AS avg_oom_adj
FROM android_lmk_events
WHERE CASE WHEN '${package}' != ''
           THEN (process_name = '${package}' OR process_name GLOB '${package}:*')
           ELSE 1 END
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY time_sec
HAVING lmk_count > 0
ORDER BY time_sec
