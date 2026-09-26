-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 380a21355baca5f8e2d2d740174e6f6897b0150f4d792c53f3b0d42de71a0f1b
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

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
