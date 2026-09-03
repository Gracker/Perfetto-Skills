-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/flutter_scrolling_analysis.skill.yaml
-- Source SHA-256: 1f345fc088535bbce0d3edac849ed979ebf199178b142f2f24cc08d716a5a5f0
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH
-- Fragment: flutter_process_identity
-- Resolves the Flutter process scope used by Flutter-specific Skills.
-- An explicit package selects that package and its child processes. Without a
-- package, select one dominant process only after paired Flutter thread
-- identity is present; generic SurfaceView or system FrameTimeline rows are
-- never sufficient.
-- Params: ${package}
flutter_thread_identity AS (
  SELECT
    p.upid,
    p.name as process_name,
    MAX(CASE WHEN t.name GLOB '[0-9]*.raster' THEN 1 ELSE 0 END) as has_flutter_raster,
    MAX(CASE WHEN t.name GLOB '[0-9]*.ui' THEN 1 ELSE 0 END) as has_flutter_ui,
    MAX(CASE WHEN t.name GLOB 'DartWorker*' THEN 1 ELSE 0 END) as has_dart_worker
  FROM process p
  LEFT JOIN thread t ON t.upid = p.upid
  WHERE p.name IS NOT NULL
  GROUP BY p.upid, p.name
),
flutter_process_candidates AS (
  SELECT
    identity.*,
    COALESCE((
      SELECT COUNT(*)
      FROM slice s
      JOIN thread_track tt ON s.track_id = tt.id
      JOIN thread t ON tt.utid = t.utid
      WHERE t.upid = identity.upid
        AND (
          t.name GLOB '[0-9]*.raster'
          OR t.name GLOB '[0-9]*.ui'
          OR t.name GLOB '[0-9]*.io'
          OR t.name GLOB 'DartWorker*'
        )
    ), 0) as flutter_activity_score
  FROM flutter_thread_identity identity
  WHERE has_flutter_raster = 1
    AND (has_flutter_ui = 1 OR has_dart_worker = 1)
),
detected_flutter_process AS (
  SELECT upid, process_name, 'thread_identity' as resolution_source
  FROM flutter_process_candidates
  ORDER BY flutter_activity_score DESC, upid ASC
  LIMIT 1
),
flutter_processes AS (
  SELECT p.upid, p.name as process_name, 'explicit_package' as resolution_source
  FROM process p
  WHERE '${package}' <> ''
    AND (p.name = '${package}' OR p.name GLOB '${package}:*')
  UNION ALL
  SELECT upid, process_name, resolution_source
  FROM detected_flutter_process
  WHERE '${package}' = ''
)
,
-- Detect TextureView mode: 1.ui present + updateTexImage/SurfaceTexture slices > 5
textureview_check AS (
  SELECT
    (SELECT COUNT(DISTINCT t.utid) FROM thread t
     WHERE t.name GLOB '*1.ui*'
       AND t.upid IN (SELECT upid FROM flutter_processes)
    ) as flutter_ui_threads,
    (SELECT COUNT(*) FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     JOIN thread t ON tt.utid = t.utid
     WHERE (s.name GLOB '*updateTexImage*' OR s.name GLOB '*SurfaceTexture*')
       AND t.upid IN (SELECT upid FROM flutter_processes)
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
  WHERE t.upid IN (SELECT upid FROM flutter_processes)
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
    AND t.upid IN (SELECT upid FROM flutter_processes)
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
