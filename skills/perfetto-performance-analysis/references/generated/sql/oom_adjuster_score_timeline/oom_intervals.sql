-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/oom_adjuster_score_timeline.skill.yaml
-- Source SHA-256: c955d048f6d17e0c4063656ab3f1b2468226e04ce68b76ef596f479b158bb973
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

SELECT
  ts,
  ROUND(dur / 1e9, 2) AS dur_sec,
  process_name,
  score AS oom_score_adj,
  bucket AS bucket_name
FROM android_oom_adj_intervals
WHERE (process_name GLOB '${process_name}*' OR '${process_name}' = '')
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC
