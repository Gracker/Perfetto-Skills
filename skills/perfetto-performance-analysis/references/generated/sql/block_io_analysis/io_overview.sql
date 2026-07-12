-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/block_io_analysis.skill.yaml
-- Source SHA-256: 6694949cda0a83aa4448782fcdc7b6b7fb8c62134598018d5f702eb571a23985
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  track.name AS io_type,
  COUNT(*) AS operation_count,
  ROUND(SUM(slice.dur) / 1e6, 2) AS total_dur_ms,
  ROUND(AVG(slice.dur) / 1e6, 2) AS avg_dur_ms,
  ROUND(MAX(slice.dur) / 1e6, 2) AS max_dur_ms
FROM slice
JOIN track ON slice.track_id = track.id
WHERE track.type = 'block_io'
  AND (${start_ts} IS NULL OR slice.ts + slice.dur > ${start_ts})
  AND (${end_ts} IS NULL OR slice.ts < ${end_ts})
GROUP BY track.name
ORDER BY total_dur_ms DESC
