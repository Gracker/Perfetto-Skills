-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scroll_session_analysis.skill.yaml
-- Source SHA-256: fd8dbf2ef3390842217b4b5877ff5a8dd65c44f0edbaaa4d59ba036370f53517
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH frames AS (
  SELECT
    s.ts,
    s.dur,
    s.dur / 1e6 AS dur_ms,
    CASE
      WHEN s.dur > ${vsync_period_ns} * 1.5 THEN 1
      ELSE 0
    END AS is_janky
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (s.name GLOB '*doFrame*' OR s.name GLOB '*Choreographer#doFrame*')
    AND t.tid = p.pid
    AND s.ts >= ${start_ts}
    AND s.ts <= ${end_ts}
)
SELECT
  ${session_id} AS session_id,
  COUNT(*) AS total_frames,
  SUM(is_janky) AS janky_frames,
  ROUND(100.0 * SUM(is_janky) / NULLIF(COUNT(*), 0), 2) AS jank_rate,
  ROUND(AVG(dur_ms), 2) AS avg_frame_ms,
  ROUND(MAX(dur_ms), 2) AS max_frame_ms,
  ROUND(MIN(dur_ms), 2) AS min_frame_ms,
  ROUND(COUNT(*) * 1e9 / NULLIF(MAX(ts + dur) - MIN(ts), 0), 1) AS estimated_fps,
  ROUND((${end_ts} - ${start_ts}) / 1e6, 1) AS duration_ms
FROM frames
