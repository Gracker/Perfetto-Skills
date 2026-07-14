-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
