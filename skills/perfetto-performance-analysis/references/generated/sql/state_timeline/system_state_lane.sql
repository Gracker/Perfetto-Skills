-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/state_timeline.skill.yaml
-- Source SHA-256: 847df75d4dff0db6d9e8a10b5d5654d248cc898fde909ce265075dfb85209401
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH trace_bounds AS (
  SELECT MIN(ts) AS t_start, MAX(ts) AS t_end
  FROM (
    SELECT ts FROM slice WHERE dur > 0
    UNION ALL
    SELECT ts FROM counter WHERE value IS NOT NULL
  )
),
-- Detect system events from known patterns in system_server / SurfaceFlinger
system_events AS (
  SELECT
    s.ts AS start_ts,
    s.ts + s.dur AS end_ts,
    CASE
      WHEN s.name GLOB '*KeyguardGoing*' OR s.name GLOB '*keyguardGoingAway*'
        THEN 'UNLOCK'
      WHEN s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*'
        THEN 'RECENT_APPS'
      WHEN (s.name GLOB '*StatusBar*expand*' OR s.name GLOB '*NotificationShade*'
            OR s.name GLOB '*StatusBarWindow*')
        AND s.dur > 10000000
        THEN 'NOTIFICATION_SHADE'
      WHEN s.name GLOB '*showSoftInput*' OR s.name GLOB '*InputMethodService*show*'
           OR s.name GLOB '*InputMethodManager*show*'
        THEN 'KEYBOARD'
      WHEN (s.name GLOB '*WindowAnimation*' OR s.name GLOB '*Transition*'
            OR s.name GLOB '*RemoteAnimation*' OR s.name GLOB '*AppTransition*')
        AND s.dur > 10000000
        THEN 'ANIMATION'
      ELSE NULL
    END AS state,
    -- Priority for overlap resolution (higher = wins)
    CASE
      WHEN s.name GLOB '*KeyguardGoing*' OR s.name GLOB '*keyguardGoingAway*' THEN 50
      WHEN s.name GLOB '*RecentsAnimation*' OR s.name GLOB '*startRecentsActivity*' THEN 40
      WHEN s.name GLOB '*StatusBar*expand*' OR s.name GLOB '*NotificationShade*'
           OR s.name GLOB '*StatusBarWindow*' THEN 30
      WHEN s.name GLOB '*showSoftInput*' OR s.name GLOB '*InputMethodService*show*'
           OR s.name GLOB '*InputMethodManager*show*' THEN 20
      ELSE 10
    END AS priority
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  WHERE s.dur > 10000000
    AND (
      p.name IN ('system_server', '/system/bin/surfaceflinger')
      OR p.name GLOB 'com.android.systemui*'
    )
    AND (
      s.name GLOB '*KeyguardGoing*'
      OR s.name GLOB '*keyguardGoingAway*'
      OR s.name GLOB '*RecentsAnimation*'
      OR s.name GLOB '*startRecentsActivity*'
      OR s.name GLOB '*StatusBar*expand*'
      OR s.name GLOB '*NotificationShade*'
      OR s.name GLOB '*StatusBarWindow*'
      OR s.name GLOB '*showSoftInput*'
      OR s.name GLOB '*InputMethodService*show*'
      OR s.name GLOB '*InputMethodManager*show*'
      OR s.name GLOB '*WindowAnimation*'
      OR s.name GLOB '*Transition*'
      OR s.name GLOB '*RemoteAnimation*'
      OR s.name GLOB '*AppTransition*'
    )
),
-- Sweep-line interval merge: produce non-overlapping segments where the
-- highest-priority event wins at each time point.
-- 1. Collect valid (non-NULL state) events
valid_events AS (
  SELECT start_ts, end_ts, state, priority
  FROM system_events
  WHERE state IS NOT NULL
),
-- 2. Extract all transition points (event starts + ends, deduplicated)
transition_points AS (
  SELECT start_ts AS ts FROM valid_events
  UNION
  SELECT end_ts AS ts FROM valid_events
),
sorted_points AS (
  SELECT ts, ROW_NUMBER() OVER (ORDER BY ts) AS rn
  FROM transition_points
),
-- 3. Create micro-segments between consecutive transition points
micro_segments AS (
  SELECT p1.ts AS seg_start, p2.ts AS seg_end
  FROM sorted_points p1
  JOIN sorted_points p2 ON p2.rn = p1.rn + 1
  WHERE p2.ts > p1.ts
),
-- 4. For each micro-segment, pick the highest-priority event covering it
segment_winners AS (
  SELECT
    ms.seg_start,
    ms.seg_end,
    ve.state,
    ROW_NUMBER() OVER (
      PARTITION BY ms.seg_start, ms.seg_end
      ORDER BY ve.priority DESC,
               (ve.end_ts - ve.start_ts) DESC,
               ve.start_ts ASC,
               ve.state ASC
    ) AS rn
  FROM micro_segments ms
  JOIN valid_events ve
    ON ve.start_ts <= ms.seg_start
   AND ve.end_ts >= ms.seg_end
),
winners AS (
  SELECT seg_start, seg_end, state
  FROM segment_winners
  WHERE rn = 1
),
-- 5. Merge consecutive segments with same state (gaps-and-islands)
island_groups AS (
  SELECT seg_start, seg_end, state,
    ROW_NUMBER() OVER (ORDER BY seg_start) -
    ROW_NUMBER() OVER (PARTITION BY state ORDER BY seg_start) AS grp
  FROM winners
),
deduped AS (
  SELECT MIN(seg_start) AS start_ts, MAX(seg_end) AS end_ts, state
  FROM island_groups
  GROUP BY state, grp
),
numbered AS (
  SELECT *, ROW_NUMBER() OVER (ORDER BY start_ts) AS rn
  FROM deduped
),
-- Gap filling with UNKNOWN
gaps AS (
  -- Leading gap
  SELECT
    (SELECT t_start FROM trace_bounds) AS start_ts,
    COALESCE((SELECT MIN(start_ts) FROM deduped), (SELECT t_end FROM trace_bounds)) AS end_ts,
    'UNKNOWN' AS state

  UNION ALL

  -- Inter-event gaps
  SELECT
    n1.end_ts AS start_ts,
    n2.start_ts AS end_ts,
    'UNKNOWN' AS state
  FROM numbered n1
  JOIN numbered n2 ON n2.rn = n1.rn + 1
  WHERE n2.start_ts > n1.end_ts

  UNION ALL

  -- Trailing gap (only when deduped has events; otherwise leading gap covers full trace)
  SELECT
    (SELECT MAX(end_ts) FROM deduped) AS start_ts,
    (SELECT t_end FROM trace_bounds) AS end_ts,
    'UNKNOWN' AS state
  WHERE EXISTS (SELECT 1 FROM deduped)
    AND (SELECT MAX(end_ts) FROM deduped) < (SELECT t_end FROM trace_bounds)
),
all_segments AS (
  SELECT start_ts, end_ts, state FROM deduped
  UNION ALL
  SELECT start_ts, end_ts, state FROM gaps
)
SELECT
  'system' AS lane,
  state,
  CASE state
    WHEN 'ANIMATION' THEN '系统动画'
    WHEN 'KEYBOARD' THEN '键盘弹出'
    WHEN 'NOTIFICATION_SHADE' THEN '通知栏'
    WHEN 'RECENT_APPS' THEN '多任务'
    WHEN 'UNLOCK' THEN '解锁'
    ELSE '未知'
  END AS state_label,
  printf('%d', start_ts) AS start_ts,
  printf('%d', end_ts) AS end_ts,
  end_ts - start_ts AS dur_ns,
  CAST((end_ts - start_ts) / 1000000 AS INT) AS dur_ms,
  'available' AS source_status,
  CASE
    WHEN state = 'UNKNOWN' THEN 'N/A'
    ELSE 'MEDIUM'
  END AS confidence
FROM all_segments
WHERE end_ts > start_ts
ORDER BY start_ts
LIMIT 500
