-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 4847d51840b9975df3dd72b632137f8edd23b91bf4ba70da3c27f6d86393eda0
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

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
