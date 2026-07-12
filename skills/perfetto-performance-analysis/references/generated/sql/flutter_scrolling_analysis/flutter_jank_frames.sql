-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
-- Source SHA-256: 1948ff2572667b9c7ccba73cb1bc9334c36b3ae6f6ae78371b7c64e154421c72
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

SELECT
  printf('%d', a.ts) AS ts,
  printf('%d', a.ts + a.dur) AS end_ts,
  ROUND(a.dur / 1e6, 2) AS dur_ms,
  CASE
    WHEN a.dur > ${vsync_period_ns} * 3 THEN 'severe'
    WHEN a.dur > ${vsync_period_ns} * 2 THEN 'bad'
    WHEN a.dur > ${vsync_period_ns} * 1.5 THEN 'jank'
    ELSE 'normal'
  END AS jank_level,
  ROUND(a.dur / CAST(${vsync_period_ns} AS REAL), 1) AS frames_dropped,
  COALESCE(a.jank_tag, '') AS jank_tag
FROM actual_frame_timeline_slice a
LEFT JOIN process p ON a.upid = p.upid
WHERE (
  '${package}' = '' OR p.name LIKE '%${package}%'
)
AND a.dur > ${vsync_period_ns} * 1.5
AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
AND (${end_ts} IS NULL OR a.ts <= ${end_ts})
ORDER BY a.dur DESC
LIMIT 30
