-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scroll_session_analysis.skill.yaml
-- Source SHA-256: 59e06a212efc4660c3d1eb10335f4fc1f33c7120448effb115823ec96915d9b5
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH frames AS (
  SELECT
    s.ts,
    s.dur,
    s.dur / 1e6 AS dur_ms,
    CASE
      WHEN s.ts < ${touch_end_ts} THEN 'touch'
      ELSE 'fling'
    END AS phase,
    ROW_NUMBER() OVER (ORDER BY s.ts) AS frame_number
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE (s.name GLOB '*doFrame*' OR s.name GLOB '*Choreographer#doFrame*' OR s.name GLOB '*DrawFrame*')
    AND s.ts >= ${start_ts}
    AND s.ts <= ${end_ts}
    AND (${__process_scope.upid} IS NULL OR p.upid = ${__process_scope.upid})
    AND (${__process_scope.upid} IS NOT NULL OR '${package}' = ''
      OR p.name = '${package}' OR p.name GLOB '${package}:*')
)
SELECT
  frame_number,
  phase,
  printf('%d', ts) as ts_str,
  printf('%d', ts + dur) as end_ts_str,
  printf('%d', dur) as dur_str,
  ROUND(dur_ms, 2) AS dur_ms,
  CASE
    WHEN dur > ${vsync_period_ns} * 3 THEN 'severe'
    WHEN dur > ${vsync_period_ns} * 2 THEN 'bad'
    WHEN dur > ${vsync_period_ns} * 1.5 THEN 'jank'
    ELSE 'normal'
  END AS jank_level,
  ROUND(dur_ms / (${vsync_period_ns} / 1e6), 1) AS frames_dropped
FROM frames
WHERE dur > ${vsync_period_ns} * 1.5  -- 超过 1.5 倍 VSync 周期为掉帧
ORDER BY dur_ms DESC
LIMIT 20
