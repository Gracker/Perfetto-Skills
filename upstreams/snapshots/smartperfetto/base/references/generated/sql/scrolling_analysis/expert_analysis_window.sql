-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH frame_bounds AS (
  SELECT
    MIN(a.ts) as min_ts,
    MAX(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END) as max_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
)
SELECT
  CASE
    WHEN COALESCE(${start_ts}, min_ts) IS NOT NULL
      THEN printf('%d', COALESCE(${start_ts}, min_ts))
    ELSE NULL
  END as window_start_ts,
  CASE
    WHEN COALESCE(${end_ts}, max_ts) IS NOT NULL
      THEN printf('%d', COALESCE(${end_ts}, max_ts))
    ELSE NULL
  END as window_end_ts,
  CASE
    WHEN COALESCE(${start_ts}, min_ts) IS NOT NULL
      AND COALESCE(${end_ts}, max_ts) IS NOT NULL
      THEN ROUND((COALESCE(${end_ts}, max_ts) - COALESCE(${start_ts}, min_ts)) / 1e6, 2)
    ELSE NULL
  END as window_ms,
  CASE
    WHEN ${start_ts} IS NOT NULL OR ${end_ts} IS NOT NULL THEN 'user_selected'
    WHEN min_ts IS NOT NULL AND max_ts IS NOT NULL THEN 'auto_frame_bounds'
    ELSE 'unavailable'
  END as window_source
FROM frame_bounds
