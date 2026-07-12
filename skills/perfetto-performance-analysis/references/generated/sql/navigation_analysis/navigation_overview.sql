-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: 1ebfd2d987dc15689b41fd76a43570d53d80c2054b688b131b355b37c3585b99
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH lifecycle AS (
  SELECT
    s.name as event_name,
    s.ts,
    s.dur,
    CASE
      WHEN s.name GLOB '*performCreate*' OR s.name GLOB '*activityStart*' THEN 'onCreate'
      WHEN s.name GLOB '*performStart*' THEN 'onStart'
      WHEN s.name GLOB '*performResume*' OR s.name GLOB '*activityResume*' THEN 'onResume'
      WHEN s.name GLOB '*performPause*' THEN 'onPause'
      WHEN s.name GLOB '*performStop*' THEN 'onStop'
      WHEN s.name GLOB '*performDestroy*' THEN 'onDestroy'
      ELSE 'other'
    END as phase
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE t.tid = p.pid
    AND p.name = '${target_process.data[0].process_name}'
    AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
    AND (${end_ts} IS NULL OR s.ts < ${end_ts})
    AND (
      s.name GLOB '*performCreate*'
      OR s.name GLOB '*performStart*'
      OR s.name GLOB '*performResume*'
      OR s.name GLOB '*performPause*'
      OR s.name GLOB '*performStop*'
      OR s.name GLOB '*performDestroy*'
      OR s.name GLOB '*activityStart*'
      OR s.name GLOB '*activityResume*'
    )
),
nav_events AS (
  SELECT
    ts,
    dur,
    dur / 1e6 as dur_ms
  FROM lifecycle
  WHERE phase IN ('onCreate', 'onStart')
)
SELECT
  (SELECT COUNT(*) FROM nav_events) as total_navigations,
  ROUND((SELECT AVG(dur_ms) FROM nav_events), 2) as avg_nav_dur_ms,
  ROUND((SELECT MAX(dur_ms) FROM nav_events), 2) as max_nav_dur_ms,
  (SELECT COUNT(*) FROM lifecycle) as total_lifecycle_events,
  (SELECT COUNT(*) FROM nav_events WHERE dur_ms > ${slow_navigation_ms|400}) as slow_navigations,
  CASE
    WHEN (SELECT AVG(dur_ms) FROM nav_events) < ${nav_rating_good_ms|200} THEN '优秀 (<200ms)'
    WHEN (SELECT AVG(dur_ms) FROM nav_events) < ${slow_navigation_ms|400} THEN '良好 (200-400ms)'
    WHEN (SELECT AVG(dur_ms) FROM nav_events) < ${nav_rating_severe_ms|700} THEN '需优化 (400-700ms)'
    ELSE '严重 (>700ms)'
  END as rating
