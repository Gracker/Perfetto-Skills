-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: 55465b17c1e74abda8e2e04bb70d0c079459a9f4095de2b56b420ac9721ee0c0
-- Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

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
    (SELECT PERCENTILE(interval_ns, 0.5)
     FROM vsync_ticks
     WHERE interval_ns > 5500000 AND interval_ns < 50000000),
    (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
     FROM expected_frame_timeline_slice
     WHERE dur > 5000000 AND dur < 50000000
       AND (${start_ts} IS NULL OR ts >= ${start_ts})
       AND (${end_ts} IS NULL OR ts < ${end_ts})),
    16666667
  ) AS INTEGER) as vsync_period_ns
),
raw_frames AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as frame_id,
    a.display_frame_token,
    a.surface_frame_token,
    a.ts,
    a.dur,
    a.layer_name,
    a.jank_type,
    a.present_type,
    a.upid,
    ROW_NUMBER() OVER (
      PARTITION BY a.upid, COALESCE(a.display_frame_token, a.surface_frame_token)
      ORDER BY a.ts, a.layer_name
    ) as row_rank
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (
      a.layer_name LIKE 'TX - ${package}%'
      OR a.layer_name = '${layer_name}'
      OR ('${package}' = '' AND '${layer_name}' = '')
    )
    AND ('${start_ts}' = '' OR a.ts >= CAST('${start_ts}' AS INTEGER))
    AND ('${end_ts}' = '' OR a.ts <= CAST('${end_ts}' AS INTEGER))
),
-- 同一 display frame token 在多 layer 会重复，先去重再做间隔分析
app_frames AS (
  SELECT
    frame_id,
    display_frame_token,
    surface_frame_token,
    ts,
    dur,
    layer_name,
    jank_type,
    present_type,
    upid,
    ts + CASE WHEN dur > 0 THEN dur ELSE 0 END as present_ts,
    LAG(ts + CASE WHEN dur > 0 THEN dur ELSE 0 END)
      OVER (PARTITION BY upid ORDER BY ts, frame_id) as prev_present_ts
  FROM raw_frames
  WHERE row_rank = 1
),
interval_analysis AS (
  SELECT
    frame_id,
    display_frame_token,
    surface_frame_token,
    ts,
    dur,
    layer_name,
    jank_type as app_jank_type,
    present_type,
    present_ts - prev_present_ts as interval_ns,
    CASE
      WHEN prev_present_ts IS NULL THEN 1
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns * 6 FROM vsync_period) THEN 1
      ELSE 0
    END as is_session_break,
    MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) as vsync_missed,
    MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period), 0) AS INTEGER), 1) as token_gap,
    CASE
      WHEN prev_present_ts IS NULL THEN 0
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns * 6 FROM vsync_period) THEN 0
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_period) * 1.5 THEN 1
      ELSE 0
    END as is_consumer_jank,
    CASE
      WHEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) = 0 THEN 'SMOOTH'
      WHEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) = 1 THEN 'MINOR_JANK'
      WHEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) <= 3 THEN 'JANK'
      WHEN MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) <= 7 THEN 'SEVERE_JANK'
      ELSE 'FROZEN'
    END as jank_severity
  FROM app_frames
  WHERE prev_present_ts IS NOT NULL
)
SELECT
  printf('%d', frame_id) as frame_id,
  layer_name,
  printf('%d', ts) as ts_str,
  ROUND(ts / 1e9, 3) as ts_sec,
  ROUND(CASE WHEN dur > 0 THEN dur ELSE 0 END / 1e6, 2) as dur_ms,
  token_gap,
  vsync_missed,
  ROUND(interval_ns / 1e6, 2) as interval_ms,
  app_jank_type,
  present_type,
  jank_severity,
  is_consumer_jank,
  -- P0-3: Decompose delay source using framework jank classification (ground truth)
  -- Note: dur from actual_frame_timeline_slice spans app→display, includes SF time,
  -- so we rely on app_jank_type from the framework instead of dur comparison.
  -- app_late = framework detected app missed its deadline
  -- sf_late = app was on time (None) or SF was the bottleneck
  -- buffer_stuffing = buffer queue full (triple-buffering backpressure)
  CASE
    WHEN app_jank_type = 'None' THEN 'sf_late'
    WHEN app_jank_type GLOB '*SurfaceFlinger*' THEN 'sf_late'
    WHEN app_jank_type GLOB '*Buffer*' THEN 'buffer_stuffing'
    ELSE 'app_late'
  END as delay_source
FROM interval_analysis
WHERE is_session_break = 0
  AND is_consumer_jank = 1
ORDER BY ts
