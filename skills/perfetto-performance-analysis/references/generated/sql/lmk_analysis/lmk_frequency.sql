-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  CAST(ts / 1e9 AS INTEGER) AS time_sec,
  COUNT(*) AS lmk_count,
  GROUP_CONCAT(process_name, ', ') AS killed_processes,
  ROUND(AVG(oom_score_adj), 0) AS avg_oom_adj
FROM android_lmk_events
WHERE CASE WHEN '${package}' != ''
           THEN process_name GLOB '*${package}*'
           ELSE 1 END
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY time_sec
HAVING lmk_count > 0
ORDER BY time_sec
