-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scene_reconstruction.skill.yaml
-- Source SHA-256: ec96c177d3117ad0a376bfbc407543f718b9c6d3a6be27998121846e11be3978
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH lifecycle_slices AS (
  SELECT
    s.ts,
    s.dur,
    s.name,
    CASE
      WHEN s.name GLOB '*activityStart*' THEN 'activityStart'
      WHEN s.name GLOB '*activityResume*' THEN 'activityResume'
      WHEN s.name GLOB '*activityPause*' THEN 'activityPause'
      WHEN s.name GLOB '*activityStop*' THEN 'activityStop'
      WHEN s.name GLOB '*activityDestroy*' THEN 'activityDestroy'
      WHEN s.name GLOB '*performCreate*' THEN 'performCreate'
      WHEN s.name GLOB '*performResume*' THEN 'performResume'
      WHEN s.name GLOB '*performPause*' THEN 'performPause'
      WHEN s.name GLOB '*performStop*' THEN 'performStop'
      WHEN s.name GLOB '*performDestroy*' THEN 'performDestroy'
      ELSE NULL
    END AS lifecycle_event,
    CASE
      WHEN s.name LIKE '%:%' THEN SUBSTR(s.name, INSTR(s.name, ':') + 1)
      ELSE s.name
    END AS activity_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE t.is_main_thread = 1
    AND (
      s.name GLOB '*activityStart*'
      OR s.name GLOB '*activityResume*'
      OR s.name GLOB '*activityPause*'
      OR s.name GLOB '*activityStop*'
      OR s.name GLOB '*activityDestroy*'
      OR s.name GLOB '*performCreate*'
      OR s.name GLOB '*performResume*'
      OR s.name GLOB '*performPause*'
      OR s.name GLOB '*performStop*'
      OR s.name GLOB '*performDestroy*'
    )
    AND s.dur > 0
),
startup_activities AS (
  SELECT
    s.ts,
    s.dur,
    s.package AS activity_name,
    'startup (' ||
      CASE
        WHEN EXISTS (
          SELECT 1 FROM android_startup_threads st
          JOIN thread_track tt ON tt.utid = st.utid
          JOIN slice sl ON sl.track_id = tt.id
          WHERE st.startup_id = s.startup_id
            AND st.is_main_thread = 1
            AND sl.name = 'bindApplication'
            AND sl.ts + sl.dur > st.ts AND sl.ts < st.ts + st.dur
        ) THEN 'cold'
        ELSE s.startup_type
      END
    || ')' AS lifecycle_event
  FROM android_startups s
  WHERE s.dur > 0
    AND EXISTS (SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name='android_startups')
)
SELECT
  printf('%d', ts) AS ts,
  activity_name,
  lifecycle_event,
  ROUND(dur / 1e6, 1) AS dur_ms
FROM (
  SELECT ts, activity_name, lifecycle_event, dur FROM lifecycle_slices WHERE lifecycle_event IS NOT NULL
  UNION ALL
  SELECT ts, activity_name, lifecycle_event, dur FROM startup_activities
)
ORDER BY ts
LIMIT 200
