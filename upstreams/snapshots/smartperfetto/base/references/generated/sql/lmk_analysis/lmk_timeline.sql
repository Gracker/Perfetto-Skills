-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: d1aa0860a3371aeb91af3a7e07f864dba1a417a0e9e9d1e3d1387ef0bb02aec2
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  printf('%d', ts) AS lmk_ts,
  process_name,
  pid,
  oom_score_adj,
  kill_reason,
  CASE
    WHEN oom_score_adj < 0 THEN 'SYSTEM'
    WHEN oom_score_adj = 0 THEN 'FOREGROUND'
    WHEN oom_score_adj <= 100 THEN 'VISIBLE'
    WHEN oom_score_adj <= 200 THEN 'PERCEPTIBLE'
    WHEN oom_score_adj <= 300 THEN 'BACKUP'
    WHEN oom_score_adj <= 500 THEN 'HEAVY_WEIGHT'
    WHEN oom_score_adj <= 700 THEN 'SERVICE'
    WHEN oom_score_adj <= 800 THEN 'HOME'
    WHEN oom_score_adj <= 900 THEN 'PREVIOUS'
    ELSE 'CACHED'
  END AS process_priority
FROM android_lmk_events
WHERE CASE WHEN '${package}' != ''
           THEN process_name GLOB '*${package}*'
           ELSE 1 END
  AND CASE WHEN ${oom_adj_threshold} IS NOT NULL
           THEN oom_score_adj <= ${oom_adj_threshold}
           ELSE 1 END
  AND (${start_ts} IS NULL OR ts > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts
