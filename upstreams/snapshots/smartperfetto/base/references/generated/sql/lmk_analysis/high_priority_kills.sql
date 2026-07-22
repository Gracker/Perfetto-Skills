-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: d1aa0860a3371aeb91af3a7e07f864dba1a417a0e9e9d1e3d1387ef0bb02aec2
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

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
