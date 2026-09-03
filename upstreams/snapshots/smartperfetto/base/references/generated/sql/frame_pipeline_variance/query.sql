-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/frame_pipeline_variance.skill.yaml
-- Source SHA-256: 371a11a05e1735c9a5ef91771956d7304d2f0613e653c48c830946646dcf6b6f
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH frames AS (
  SELECT
    a.ts,
    a.dur / 1e6 as frame_ms
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
),
deltas AS (
  SELECT
    ts,
    frame_ms,
    ABS(frame_ms - LAG(frame_ms) OVER (ORDER BY ts)) as delta_ms
  FROM frames
)
SELECT
  COUNT(*) as total_frames,
  ROUND(AVG(frame_ms), 2) as avg_frame_ms,
  ROUND(SQRT(MAX(AVG(frame_ms * frame_ms) - AVG(frame_ms) * AVG(frame_ms), 0)), 2) as stddev_ms,
  ROUND(AVG(COALESCE(delta_ms, 0)), 2) as avg_delta_ms,
  SUM(CASE WHEN COALESCE(delta_ms, 0) >= ${transition_threshold_ms|8} THEN 1 ELSE 0 END) as high_variance_transitions,
  CASE
    WHEN AVG(COALESCE(delta_ms, 0)) >= ${transition_threshold_ms|8} THEN 'high'
    WHEN AVG(COALESCE(delta_ms, 0)) >= ${transition_threshold_ms|8} * 0.5 THEN 'medium'
    ELSE 'low'
  END as variance_level
FROM deltas
