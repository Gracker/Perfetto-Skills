-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
-- Source SHA-256: 1948ff2572667b9c7ccba73cb1bc9334c36b3ae6f6ae78371b7c64e154421c72
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH flutter_frames AS (
  SELECT
    a.ts,
    a.dur,
    a.dur / 1e6 AS dur_ms,
    a.jank_type,
    a.jank_tag,
    a.on_time_finish
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (
    '${package}' = '' OR p.name LIKE '%${package}%'
  )
  AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR a.ts <= ${end_ts})
)
SELECT
  COUNT(*) AS total_frames,
  ROUND(AVG(dur_ms), 2) AS avg_frame_ms,
  ROUND(MAX(dur_ms), 2) AS max_frame_ms,
  ROUND(MIN(dur_ms), 2) AS min_frame_ms,
  SUM(CASE WHEN dur > ${vsync_period_ns|16666667} * 1.5 THEN 1 ELSE 0 END) AS jank_frames,
  SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) AS reported_jank_frames,
  ROUND(
    100.0 * SUM(CASE WHEN dur > ${vsync_period_ns|16666667} * 1.5 THEN 1 ELSE 0 END) / MAX(COUNT(*), 1),
    1
  ) AS jank_rate_pct,
  CASE
    WHEN COUNT(*) > 0 AND MAX(ts + dur) > MIN(ts) THEN
      ROUND(COUNT(*) * 1e9 / NULLIF(MAX(ts + dur) - MIN(ts), 0), 1)
    ELSE 0
  END AS estimated_fps
FROM flutter_frames
