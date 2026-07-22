-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/chrome_scroll_jank_frame_timeline.skill.yaml
-- Source SHA-256: 2aa88e4f3cc40101c7a97eefeb3cfa517026c5c827e22d0cd8894af2a57da2a4
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH
scrolls AS (
  SELECT COUNT(*) AS count
  FROM chrome_scrolls
  WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
scroll_stats AS (
  SELECT COUNT(*) AS count
  FROM chrome_scroll_stats
),
v4_frames AS (
  SELECT
    COUNT(*) AS frame_count,
    SUM(CASE WHEN is_janky THEN 1 ELSE 0 END) AS jank_count
  FROM chrome_scroll_jank_v4_results
  WHERE (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
extend_vsync AS (
  SELECT
    COUNT(*) AS extend_vsync_count,
    SUM(CASE
      WHEN extract_arg(arg_set_id, 'android_choreographer_frame_callback_data.preferred_frame_timeline_index') IS NOT NULL
        OR extract_arg(arg_set_id, 'android_choreographer_frame_callback_data.chrome_preferred_frame_timeline.vsync_id') IS NOT NULL
      THEN 1 ELSE 0
    END) AS preferred_frame_timeline_count
  FROM slice
  WHERE name = 'Extend_VSync'
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
SELECT
  (SELECT count FROM scrolls) AS chrome_scroll_count,
  (SELECT count FROM scroll_stats) AS chrome_scroll_stats_count,
  (SELECT frame_count FROM v4_frames) AS chrome_scroll_v4_frame_count,
  COALESCE((SELECT jank_count FROM v4_frames), 0) AS chrome_scroll_v4_jank_count,
  (SELECT extend_vsync_count FROM extend_vsync) AS extend_vsync_count,
  COALESCE((SELECT preferred_frame_timeline_count FROM extend_vsync), 0) AS preferred_frame_timeline_count,
  CASE
    WHEN (SELECT count FROM scrolls) > 0 OR (SELECT frame_count FROM v4_frames) > 0 THEN 'chrome_scroll_available'
    WHEN (SELECT extend_vsync_count FROM extend_vsync) > 0 THEN 'frame_timeline_only'
    ELSE 'no_chrome_scroll_data'
  END AS status
