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
vsync_intervals AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
flutter_timing AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END as vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      ${vsync_period_ns},
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      (SELECT CAST(PERCENTILE(dur, 50) AS INTEGER)
       FROM expected_frame_timeline_slice
       WHERE dur > 5000000 AND dur < 50000000
         AND (${start_ts} IS NULL OR ts >= ${start_ts})
         AND (${end_ts} IS NULL OR ts < ${end_ts})),
      16666667
    ) AS INTEGER) as raw_ns
  )
),
-- FLUTTER_OVERVIEW_CONSUMER_CTES_BEGIN
flutter_frame_rows AS (
  SELECT
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key,
    a.ts,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as dur,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END / 1e6 as dur_ms,
    COALESCE(a.jank_type, 'None') as jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.layer_name,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts, COALESCE(a.display_frame_token, a.surface_frame_token)) as prev_present_ts,
    CASE
      WHEN a.jank_type GLOB '*Self Jank*' OR android_is_app_jank_type(a.jank_type) THEN 'APP'
      WHEN a.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN a.jank_type GLOB '*Buffer Stuffing*' THEN 'BUFFER_STUFFING'
      WHEN android_is_sf_jank_type(a.jank_type) THEN 'SF'
      WHEN a.jank_type = 'None' OR a.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END as jank_responsibility
  FROM actual_frame_timeline_slice a
  JOIN flutter_processes fp ON a.upid = fp.upid
  WHERE (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts <= ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
flutter_row_signals AS (
  SELECT
    *,
    CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND (jank_responsibility != 'BUFFER_STUFFING' OR android_is_missed_frame_type(jank_type)) THEN 1
      WHEN jank_responsibility = 'BUFFER_STUFFING'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM flutter_timing) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM flutter_timing) * 6 THEN 1
      ELSE 0
    END as row_is_consumer_jank
  FROM flutter_frame_rows
),
ranked_flutter_rows AS (
  SELECT
    *,
    MAX(row_is_consumer_jank) OVER (PARTITION BY frame_key) as is_consumer_jank,
    ROW_NUMBER() OVER (
      PARTITION BY frame_key
      ORDER BY row_is_consumer_jank DESC, dur DESC, layer_name ASC
    ) as frame_row_rank
  FROM flutter_row_signals
),
flutter_frames AS (
  SELECT ts, dur, dur_ms, jank_type, is_consumer_jank
  FROM ranked_flutter_rows
  WHERE frame_row_rank = 1
)
-- FLUTTER_OVERVIEW_CONSUMER_CTES_END
SELECT
  COUNT(*) AS total_frames,
  ROUND(AVG(dur_ms), 2) AS avg_frame_ms,
  ROUND(MAX(dur_ms), 2) AS max_frame_ms,
  ROUND(MIN(dur_ms), 2) AS min_frame_ms,
  SUM(is_consumer_jank) AS jank_frames,
  SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) AS reported_jank_frames,
  ROUND(
    100.0 * SUM(is_consumer_jank) / MAX(COUNT(*), 1),
    1
  ) AS jank_rate_pct,
  CASE
    WHEN COUNT(*) > 0 AND MAX(ts + dur) > MIN(ts) THEN
      ROUND(COUNT(*) * 1e9 / NULLIF(MAX(ts + dur) - MIN(ts), 0), 1)
    ELSE 0
  END AS estimated_fps,
  CASE
    WHEN (SELECT COUNT(*) FROM flutter_processes) = 0 THEN 'no_flutter_process_identity'
    WHEN COUNT(*) = 0 THEN 'no_flutter_process_frame_timeline'
    ELSE 'scoped_flutter_frame_timeline'
  END AS evidence_status,
  COALESCE((SELECT GROUP_CONCAT(process_name, '; ') FROM flutter_processes), '') AS process_scope,
  'display_frame_present_type_hybrid' AS evidence_scope,
  'on_time_present_gap_is_not_jank' AS claim_boundary
FROM flutter_frames
