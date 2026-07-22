-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
-- Source SHA-256: 1948ff2572667b9c7ccba73cb1bc9334c36b3ae6f6ae78371b7c64e154421c72
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

SELECT
  s.name AS slice_name,
  printf('%d', s.ts) AS ts,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  CASE
    WHEN s.name LIKE '%DrawToSurface%' THEN 'draw_to_surface'
    WHEN s.name LIKE '%EntityPass%' THEN 'impeller_render'
    WHEN s.name LIKE '%SkGpu%' THEN 'skia_render'
    WHEN s.name LIKE '%Compositor%' THEN 'compositor'
    ELSE 'other'
  END AS category
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (
  '${package}' = '' OR p.name LIKE '%${package}%'
)
AND t.name GLOB '*1.raster*'
AND s.dur > ${vsync_period_ns}
AND s.depth = 0
AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
AND (${end_ts} IS NULL OR s.ts <= ${end_ts})
ORDER BY s.dur DESC
LIMIT 20
