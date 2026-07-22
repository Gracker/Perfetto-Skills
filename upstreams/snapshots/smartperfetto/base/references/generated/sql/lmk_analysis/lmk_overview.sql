-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: d1aa0860a3371aeb91af3a7e07f864dba1a417a0e9e9d1e3d1387ef0bb02aec2
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  kill_reason,
  COUNT(*) AS kill_count,
  GROUP_CONCAT(DISTINCT process_name) AS killed_processes,
  ROUND(AVG(oom_score_adj), 0) AS avg_oom_adj,
  MIN(oom_score_adj) AS min_oom_adj
FROM android_lmk_events
WHERE CASE WHEN '${package}' != ''
           THEN process_name GLOB '*${package}*'
           ELSE 1 END
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY kill_reason
ORDER BY kill_count DESC
