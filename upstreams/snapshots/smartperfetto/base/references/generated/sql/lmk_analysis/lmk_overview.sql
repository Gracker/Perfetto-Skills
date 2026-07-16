-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909

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
