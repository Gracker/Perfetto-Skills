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
scoped_flutter_jank_frames AS (
  SELECT a.*
  FROM actual_frame_timeline_slice a
  JOIN flutter_processes fp ON a.upid = fp.upid
  WHERE a.dur > ${vsync_period_ns} * 1.5
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts <= ${end_ts})
)
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
FROM scoped_flutter_jank_frames a
ORDER BY a.dur DESC
LIMIT 30
