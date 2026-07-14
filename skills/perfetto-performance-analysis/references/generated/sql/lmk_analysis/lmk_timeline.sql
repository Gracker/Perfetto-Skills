-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/lmk_analysis.skill.yaml
-- Source SHA-256: 32494b794e68cb6976f27938f66c022758ebf4fcc0826baa535203c36b6aaceb
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
