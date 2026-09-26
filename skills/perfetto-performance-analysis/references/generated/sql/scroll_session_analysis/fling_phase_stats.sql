-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scroll_session_analysis.skill.yaml
-- Source SHA-256: 59e06a212efc4660c3d1eb10335f4fc1f33c7120448effb115823ec96915d9b5
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH fling_frames AS (
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
    AND (${__process_scope.upid} IS NULL OR p.upid = ${__process_scope.upid})
    AND (${__process_scope.upid} IS NOT NULL OR '${package}' = ''
      OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND s.ts >= ${fling_start_ts}
    AND s.ts <= ${fling_end_ts}
)
SELECT
  'fling' AS phase,
  COUNT(*) AS frame_count,
  SUM(is_janky) AS janky_count,
  ROUND(100.0 * SUM(is_janky) / NULLIF(COUNT(*), 0), 2) AS jank_rate,
  ROUND(AVG(dur_ms), 2) AS avg_frame_ms,
  ROUND(MAX(dur_ms), 2) AS max_frame_ms,
  ROUND(COUNT(*) * 1e9 / NULLIF(MAX(ts + dur) - MIN(ts), 0), 1) AS fps,
  ROUND((${fling_end_ts} - ${fling_start_ts}) / 1e6, 1) AS duration_ms
FROM fling_frames
