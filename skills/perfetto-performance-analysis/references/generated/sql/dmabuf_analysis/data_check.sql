-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 82544957bb27c764d3304e2acc9a3306fa7fab10dc9b095bcfe0cae0798b53f6
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

SELECT CASE WHEN EXISTS (
  SELECT 1 FROM android_dmabuf_allocs
  WHERE (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
) THEN 1 ELSE 0 END as has_data
