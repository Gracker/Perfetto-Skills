-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
-- Source SHA-256: 1948ff2572667b9c7ccba73cb1bc9334c36b3ae6f6ae78371b7c64e154421c72
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH
-- Detect TextureView mode: 1.ui present + updateTexImage/SurfaceTexture slices > 5
textureview_check AS (
  SELECT
    (SELECT COUNT(DISTINCT t.utid) FROM thread t
     JOIN process p ON t.upid = p.upid
     WHERE t.name GLOB '*1.ui*'
       AND ('${package}' = '' OR p.name LIKE '%${package}%')
    ) as flutter_ui_threads,
    (SELECT COUNT(*) FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     JOIN thread t ON tt.utid = t.utid
     WHERE (s.name GLOB '*updateTexImage*' OR s.name GLOB '*SurfaceTexture*')
       AND s.dur > 0
    ) as texture_view_slices
),
is_textureview AS (
  SELECT (flutter_ui_threads > 0 AND texture_view_slices > 5) as flag
  FROM textureview_check
),
-- Standard Flutter threads: 1.ui / 1.raster / 1.io
flutter_threads AS (
  SELECT
    CASE
      WHEN t.name GLOB '*1.ui*' THEN 'UI (Dart)'
      WHEN t.name GLOB '*1.raster*' THEN 'Raster (GPU)'
      WHEN t.name GLOB '*1.io*' THEN 'IO (Decode)'
    END AS role,
    s.dur / 1e6 AS dur_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE ('${package}' = '' OR p.name LIKE '%${package}%')
    AND (t.name GLOB '*1.ui*' OR t.name GLOB '*1.raster*' OR t.name GLOB '*1.io*')
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts <= ${end_ts})
),
-- TextureView mode: RenderThread composition (updateTexImage, DrawFrame, queueBuffer)
textureview_threads AS (
  SELECT
    'RenderThread (TextureView)' AS role,
    s.dur / 1e6 AS dur_ms
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.name = 'RenderThread'
    AND (s.name GLOB '*updateTexImage*' OR s.name GLOB '*DrawFrame*' OR s.name GLOB '*queueBuffer*')
    AND s.dur > 0
    AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts <= ${end_ts})
    AND (SELECT flag FROM is_textureview) = 1
),
all_threads AS (
  SELECT role, dur_ms FROM flutter_threads
  UNION ALL
  SELECT role, dur_ms FROM textureview_threads
)
SELECT
  role,
  COUNT(*) AS slice_count,
  ROUND(AVG(dur_ms), 2) AS avg_ms,
  ROUND(MAX(dur_ms), 2) AS max_ms,
  ROUND(SUM(dur_ms), 1) AS total_ms,
  SUM(CASE WHEN dur_ms > (${vsync_period_ns|16666667} / 1e6 * 1.5) THEN 1 ELSE 0 END) AS over_budget_count
FROM all_threads
GROUP BY role
ORDER BY total_ms DESC
