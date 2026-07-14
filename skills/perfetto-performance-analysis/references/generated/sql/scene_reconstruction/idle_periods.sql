-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH key_events AS (
  SELECT read_time AS ts
  FROM android_input_events
  WHERE event_type = 'MOTION'
    AND event_action = 'DOWN'
    AND process_name NOT IN ('system_server', '/system/bin/inputflinger')
    AND process_name NOT GLOB 'com.android.systemui*'

  UNION ALL

  SELECT ts
  FROM android_startups
  WHERE dur > 0

  UNION ALL

  SELECT ts
  FROM slice
  WHERE dur > 0
    AND (
      -- Screen unlock signals: keep lock-screen related patterns only.
      -- Avoid generic '*unlock*' to prevent false positives (e.g. render/mutex unlock slices).
      LOWER(name) LIKE '%keyguard%dismiss%'
      OR LOWER(name) LIKE '%keyguard%unlock%'
      OR LOWER(name) LIKE '%lockscreen%unlock%'
      OR LOWER(name) LIKE '%unlock%screen%'
      OR LOWER(name) LIKE '%notificationpanel%expand%'
      OR LOWER(name) LIKE '%notificationpanel%collapse%'
      OR (LOWER(name) LIKE '%splitscreen%' AND dur > 500000000)
    )
    AND LOWER(name) NOT LIKE '%unlockcanvasandpost%'
    AND LOWER(name) NOT LIKE '%unlockandpost%'
    AND LOWER(name) != 'unlock'
),
ordered_events AS (
  SELECT
    ts,
    LEAD(ts) OVER (ORDER BY ts) AS next_ts
  FROM key_events
),
idle_windows AS (
  SELECT
    ts AS start_ts,
    next_ts AS end_ts,
    next_ts - ts AS gap_ns
  FROM ordered_events
  WHERE next_ts IS NOT NULL
    AND next_ts - ts >= 800000000
)
SELECT
  printf('%d', start_ts) AS ts,
  printf('%d', gap_ns) AS dur,
  '空闲 (' || CAST(gap_ns / 1000000 AS INT) || 'ms)' AS event,
  CASE
    WHEN gap_ns >= 3000000000 THEN '高'
    WHEN gap_ns >= 1500000000 THEN '中'
    ELSE '低'
  END AS confidence,
  'idle' AS category
FROM idle_windows
ORDER BY start_ts
LIMIT 120
