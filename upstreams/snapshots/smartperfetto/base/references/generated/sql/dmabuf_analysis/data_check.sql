-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 15c7918ef202638b9eb23a3c1e4d1b3f3ab1e091ae7c43784b1858386b89227d
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT CASE WHEN EXISTS (
  SELECT 1 FROM android_dmabuf_allocs
  WHERE (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
) THEN 1 ELSE 0 END as has_data
