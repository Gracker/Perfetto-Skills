-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: bd6cecfa7dc06e2b74d023498fb38d336bec28f1214c4364880f4091e2ffb7fa
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH
vsync_ticks AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_period AS (
  SELECT CAST(COALESCE(
    (SELECT PERCENTILE(interval_ns, 50)
     FROM vsync_ticks
     WHERE interval_ns > 5500000 AND interval_ns < 50000000),
    (SELECT CAST(PERCENTILE(dur, 50) AS INTEGER)
     FROM expected_frame_timeline_slice
     WHERE dur > 5000000 AND dur < 50000000
       AND (${start_ts} IS NULL OR ts >= ${start_ts})
       AND (${end_ts} IS NULL OR ts < ${end_ts})),
    16666667
  ) AS INTEGER) as vsync_period_ns
),
-- CONSUMER_JANK_SEVERITY_CTES_BEGIN
app_frame_rows AS (
  SELECT
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key,
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
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (
      a.layer_name LIKE 'TX - ${package}%'
      OR a.layer_name = '${layer_name}'
      OR ('${package}' = '' AND '${layer_name}' = '')
    )
    AND ('${start_ts}' = '' OR a.ts >= CAST('${start_ts}' AS INTEGER))
    AND ('${end_ts}' = '' OR a.ts <= CAST('${end_ts}' AS INTEGER))
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
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_period) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_period) * 6 THEN 1
      ELSE 0
    END as row_is_consumer_jank,
    CASE
      WHEN prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_period) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_period) * 6
      THEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0)
      ELSE 0
    END as row_vsync_missed
  FROM app_frame_rows
),
ranked_jank_rows AS (
  SELECT
    *,
    MAX(row_is_consumer_jank) OVER (PARTITION BY frame_key) as is_consumer_jank,
    MAX(row_vsync_missed) OVER (PARTITION BY frame_key) as observed_vsync_missed,
    ROW_NUMBER() OVER (
      PARTITION BY frame_key
      ORDER BY row_is_consumer_jank DESC, dur DESC, layer_name ASC
    ) as frame_row_rank
  FROM jank_row_signals
),
frame_signals AS (
  SELECT
    frame_key,
    is_consumer_jank,
    CASE
      WHEN is_consumer_jank = 0 THEN 0
      WHEN observed_vsync_missed > 0 THEN observed_vsync_missed
      ELSE 1
    END as vsync_missed
  FROM ranked_jank_rows
  WHERE frame_row_rank = 1
),
severity_analysis AS (
  SELECT
    CASE
      WHEN is_consumer_jank = 0 THEN 'SMOOTH_OR_ON_TIME'
      WHEN vsync_missed <= 1 THEN 'MINOR_JANK (missed=1)'
      WHEN vsync_missed <= 3 THEN 'JANK (missed=2-3)'
      WHEN vsync_missed <= 7 THEN 'SEVERE_JANK (missed=4-7)'
      ELSE 'FROZEN (missed>=8)'
    END as severity
  FROM frame_signals
)
-- CONSUMER_JANK_SEVERITY_CTES_END
SELECT
  severity,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) as percentage
FROM severity_analysis
GROUP BY severity
ORDER BY
  CASE severity
    WHEN 'SMOOTH_OR_ON_TIME' THEN 1
    WHEN 'MINOR_JANK (missed=1)' THEN 2
    WHEN 'JANK (missed=2-3)' THEN 3
    WHEN 'SEVERE_JANK (missed=4-7)' THEN 4
    ELSE 5
  END
