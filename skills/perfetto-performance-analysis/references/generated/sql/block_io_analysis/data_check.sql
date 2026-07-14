-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

SELECT CASE WHEN EXISTS (
  SELECT 1 FROM slice
  JOIN track ON slice.track_id = track.id
  WHERE track.type = 'block_io'
    AND (${start_ts} IS NULL OR slice.ts + slice.dur > ${start_ts})
    AND (${end_ts} IS NULL OR slice.ts < ${end_ts})
) THEN 1 ELSE 0 END as has_data
