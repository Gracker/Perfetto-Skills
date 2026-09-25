-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/oom_adjuster_score_timeline.skill.yaml
-- Source SHA-256: ff973a5e2e8c49d1bd0d2464554603f3db5abd2068e48b2f2205d8f34559dce3
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  ts,
  ROUND(dur / 1e9, 2) AS dur_sec,
  process_name,
  score AS oom_score_adj,
  bucket AS bucket_name
FROM android_oom_adj_intervals
WHERE ('${process_name}' = '' OR process_name = '${process_name}' OR process_name GLOB '${process_name}:*')
  AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts < ${end_ts})
ORDER BY ts ASC
