-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH io_slices AS (
  SELECT
    slice.ts,
    slice.dur,
    extract_arg(track.dimension_arg_set_id, 'block_device') AS dev
  FROM slice
  JOIN track ON slice.track_id = track.id
  WHERE track.type = 'block_io'
    AND (${start_ts} IS NULL OR slice.ts + slice.dur > ${start_ts})
    AND (${end_ts} IS NULL OR slice.ts < ${end_ts})
)
SELECT
  dev,
  COUNT(*) AS io_count,
  ROUND(SUM(dur) / 1e6, 2) AS total_io_ms,
  ROUND(AVG(dur) / 1e6, 2) AS avg_io_ms,
  ROUND(MAX(dur) / 1e6, 2) AS max_io_ms
FROM io_slices
WHERE dev IS NOT NULL
  AND (CASE WHEN '${device}' != '' THEN dev GLOB '*${device}*' ELSE 1 END)
GROUP BY dev
ORDER BY total_io_ms DESC
