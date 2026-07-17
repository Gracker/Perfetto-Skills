-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/chrome_scroll_jank_frame_timeline.skill.yaml
-- Source SHA-256: 2aa88e4f3cc40101c7a97eefeb3cfa517026c5c827e22d0cd8894af2a57da2a4
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH extend_vsync_slices AS (
  SELECT
    id,
    arg_set_id,
    ts,
    dur,
    ts + extract_arg(
      arg_set_id,
      'android_choreographer_frame_callback_data.frame_time_us'
    ) * 1000 - TO_MONOTONIC(ts) AS frame_ts,
    extract_arg(
      arg_set_id,
      'android_choreographer_frame_callback_data.preferred_frame_timeline_index'
    ) AS preferred_timeline_index,
    extract_arg(
      arg_set_id,
      'android_choreographer_frame_callback_data.chrome_preferred_frame_timeline.vsync_id'
    ) AS chrome_preferred_vsync_id
  FROM slice
  WHERE name = 'Extend_VSync'
    AND (${start_ts} IS NULL OR ts + dur > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
SELECT
  ev.id AS extend_vsync_slice_id,
  printf('%d', ev.ts) AS ts,
  printf('%d', COALESCE(ev.frame_ts, ev.ts)) AS frame_ts,
  ev.preferred_timeline_index,
  ev.chrome_preferred_vsync_id,
  CASE
    WHEN ev.chrome_preferred_vsync_id IS NOT NULL THEN 'chrome_preferred_frame_timeline'
    WHEN ev.preferred_timeline_index IS NOT NULL THEN 'preferred_frame_timeline_index'
    ELSE 'unknown'
  END AS preferred_source
FROM extend_vsync_slices AS ev
WHERE ev.preferred_timeline_index IS NOT NULL
  OR ev.chrome_preferred_vsync_id IS NOT NULL
ORDER BY ev.ts
LIMIT 100
