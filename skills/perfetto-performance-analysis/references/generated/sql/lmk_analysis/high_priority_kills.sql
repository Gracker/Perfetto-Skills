-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 4847d51840b9975df3dd72b632137f8edd23b91bf4ba70da3c27f6d86393eda0
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

SELECT
  process_name,
  COUNT(*) AS kill_count,
  MIN(oom_score_adj) AS min_oom_adj,
  GROUP_CONCAT(DISTINCT kill_reason) AS kill_reasons,
  printf('%d', MIN(ts)) AS first_kill_ts,
  printf('%d', MAX(ts)) AS last_kill_ts
FROM android_lmk_events
WHERE oom_score_adj <= 200
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
GROUP BY process_name
ORDER BY min_oom_adj, kill_count DESC
