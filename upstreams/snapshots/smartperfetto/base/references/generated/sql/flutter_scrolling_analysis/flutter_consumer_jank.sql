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
vsync_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 50)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
-- FLUTTER_CONSUMER_JANK_CTES_BEGIN
flutter_app_frames AS (
  SELECT
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key,
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as dur,
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
  WHERE 1 = 1
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
jank_row_signals AS (
  SELECT
    *,
    CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND (jank_responsibility != 'BUFFER_STUFFING' OR android_is_missed_frame_type(jank_type)) THEN 1
      WHEN jank_responsibility = 'BUFFER_STUFFING'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config) * 6 THEN 1
      ELSE 0
    END as row_is_consumer_jank
  FROM flutter_app_frames
),
ranked_jank_rows AS (
  SELECT
    *,
    MAX(row_is_consumer_jank) OVER (PARTITION BY frame_key) as is_consumer_jank,
    ROW_NUMBER() OVER (
      PARTITION BY frame_key
      ORDER BY
        row_is_consumer_jank DESC,
        CASE jank_responsibility
          WHEN 'APP' THEN 1
          WHEN 'SF' THEN 2
          WHEN 'BUFFER_STUFFING' THEN 3
          WHEN 'UNKNOWN' THEN 4
          ELSE 5
        END,
        dur DESC,
        layer_name ASC
    ) as frame_row_rank
  FROM jank_row_signals
),
jank_analysis AS (
  SELECT jank_type, dur, is_consumer_jank
  FROM ranked_jank_rows
  WHERE frame_row_rank = 1
)
-- FLUTTER_CONSUMER_JANK_CTES_END
SELECT
  jank_type,
  COUNT(*) as count,
  -- 非 BS 以 Late/Dropped present 为权威；BS 才用同 layer gap 二次验证。
  SUM(is_consumer_jank) as real_jank_count,
  -- 隐藏掉帧（jank_type=None 且 present_type 明确 Late/Dropped）
  SUM(CASE WHEN jank_type = 'None' AND is_consumer_jank = 1 THEN 1 ELSE 0 END) as hidden_jank_count,
  -- 假阳性（jank_type 报告掉帧，但消费证据未确认）
  SUM(CASE WHEN jank_type != 'None' AND is_consumer_jank = 0 THEN 1 ELSE 0 END) as false_positive,
  CAST(ROUND(AVG(CASE WHEN dur > 0 THEN dur ELSE NULL END)) AS INTEGER) as avg_dur,
  CASE
    WHEN jank_type GLOB '*App*' OR jank_type = 'Self Jank' THEN '标签:App'
    WHEN jank_type GLOB '*SurfaceFlinger*' THEN '标签:SurfaceFlinger'
    WHEN jank_type GLOB '*Buffer*' THEN '标签:Buffer Stuffing(需验证)'
    WHEN jank_type = 'None' THEN '标签:None(仅 Late/Dropped 可记隐藏掉帧)'
    ELSE '标签:Other'
  END as responsibility,
  'display_frame_present_type_hybrid' as evidence_scope,
  'on_time_present_gap_is_not_jank' as claim_boundary
FROM jank_analysis
GROUP BY jank_type
ORDER BY real_jank_count DESC, count DESC
LIMIT 10
