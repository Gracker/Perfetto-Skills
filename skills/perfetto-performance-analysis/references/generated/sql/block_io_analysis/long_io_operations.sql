-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

SELECT
  printf('%d', slice.ts) AS ts,
  track.name AS io_type,
  ROUND(slice.dur / 1e6, 2) AS dur_ms,
  extract_arg(track.dimension_arg_set_id, 'block_device') AS dev
FROM slice
JOIN track ON slice.track_id = track.id
WHERE track.type = 'block_io'
  AND slice.dur / 1e6 > 10
  AND (${start_ts} IS NULL OR slice.ts + slice.dur > ${start_ts})
  AND (${end_ts} IS NULL OR slice.ts < ${end_ts})
  AND (CASE WHEN '${device}' != ''
            THEN extract_arg(track.dimension_arg_set_id, 'block_device') GLOB '*${device}*'
            ELSE 1 END)
ORDER BY slice.dur DESC
LIMIT 50
