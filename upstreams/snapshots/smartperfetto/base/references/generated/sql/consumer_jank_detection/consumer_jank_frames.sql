-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: 4b5eabe1c5639d55456e498bdf6125fda0f49f1b49a216536b0f7ffde8cf04c7
-- Source commit: 34565222fe4f57b64349758a76221c4144e5d09e

WITH
vsync_ticks AS (
  SELECT
    c.ts - LAG(c.ts) OVER (PARTITION BY c.track_id ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_period AS (
  SELECT CAST((SELECT PERCENTILE(interval_ns, 50)
    FROM vsync_ticks
    WHERE interval_ns > 5500000 AND interval_ns < 50000000
  ) AS INTEGER) as vsync_period_ns
),
-- CONSUMER_JANK_FRAME_CTES_BEGIN
app_frame_rows AS (
  SELECT
    CASE
      WHEN a.display_frame_token IS NOT NULL
        THEN 'display:' || CAST(a.display_frame_token AS TEXT)
      WHEN a.surface_frame_token IS NOT NULL
        THEN 'surface:' || COALESCE(a.layer_name, '') || ':' || CAST(a.surface_frame_token AS TEXT)
      ELSE NULL
    END as frame_key,
    COALESCE(a.display_frame_token, a.surface_frame_token) as frame_id,
    a.display_frame_token,
    a.surface_frame_token,
    a.ts,
    CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as dur,
    a.layer_name,
    COALESCE(a.jank_type, 'None') as jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.upid,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    MAX(CASE WHEN a.dur > 0 AND a.present_type != 'Dropped Frame' THEN a.ts + a.dur END)
      OVER (PARTITION BY a.upid, a.layer_name
        ORDER BY a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END, COALESCE(a.display_frame_token, a.surface_frame_token)
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) as prev_present_ts,
    MIN(CASE WHEN a.dur > 0 AND a.present_type != 'Dropped Frame' THEN a.ts + a.dur END)
      OVER (PARTITION BY a.upid, a.layer_name
        ORDER BY a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END, COALESCE(a.display_frame_token, a.surface_frame_token)
        ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING) as next_present_ts,
    SUM(CASE WHEN a.dur > 0 AND a.present_type != 'Dropped Frame' THEN 1 ELSE 0 END)
      OVER (PARTITION BY a.upid, a.layer_name) as presented_sample_count,
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
  WHERE a.layer_name IS NOT NULL
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (
      a.layer_name LIKE 'TX - ${package}%'
      OR a.layer_name = '${layer_name}'
      OR ('${package}' = '' AND '${layer_name}' = '')
    )
    AND ('${start_ts}' = '' OR a.ts >= CAST('${start_ts}' AS INTEGER))
    AND ('${end_ts}' = '' OR a.ts <= CAST('${end_ts}' AS INTEGER))
),
jank_row_signals AS (
  SELECT
    *,
    CASE
      WHEN present_type = 'Dropped Frame' THEN 1
      WHEN jank_type NOT GLOB '*Buffer Stuffing*' THEN
        CASE WHEN present_type = 'Late Present' THEN 1 ELSE 0 END
      -- A tag or mixed deadline is not proof of a presentation gap.
      WHEN dur <= 0 OR prev_present_ts IS NULL
        OR (SELECT vsync_period_ns FROM vsync_period) IS NULL
        OR present_ts - prev_present_ts <= 0
        OR present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_period) * 6 THEN NULL
      WHEN present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_period) * 1.5 THEN 1
      ELSE 0
    END as row_is_consumer_jank,
    CASE WHEN jank_type GLOB '*Buffer Stuffing*' AND dur > 0
      AND present_type != 'Dropped Frame' AND presented_sample_count >= 6
      AND present_ts - prev_present_ts BETWEEN (SELECT vsync_period_ns FROM vsync_period) * 0.75 AND (SELECT vsync_period_ns FROM vsync_period) * 1.25
      AND next_present_ts - present_ts BETWEEN (SELECT vsync_period_ns FROM vsync_period) * 0.75 AND (SELECT vsync_period_ns FROM vsync_period) * 1.25
      THEN 1 ELSE 0 END as row_is_steady_stuffing,
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
    CASE
      WHEN MAX(row_is_consumer_jank) OVER (PARTITION BY frame_key) = 1 THEN 1
      WHEN COUNT(row_is_consumer_jank) OVER (PARTITION BY frame_key) < COUNT(*) OVER (PARTITION BY frame_key) THEN NULL
      ELSE 0
    END as is_consumer_jank,
    MAX(row_is_steady_stuffing) OVER (PARTITION BY frame_key) as is_steady_stuffing,
    MAX(row_vsync_missed) OVER (PARTITION BY frame_key) as observed_vsync_missed,
    ROW_NUMBER() OVER (
      PARTITION BY frame_key
      ORDER BY
        row_is_consumer_jank DESC,
        CASE jank_responsibility
          WHEN 'APP' THEN 1
          WHEN 'SF' THEN 2
          WHEN 'BUFFER_STUFFING' THEN 3
          WHEN 'UNKNOWN' THEN 4
          ELSE 5
        END,
        dur DESC,
        layer_name ASC
    ) as frame_row_rank
  FROM jank_row_signals
),
frame_signals AS (
  SELECT
    frame_key,
    frame_id,
    display_frame_token,
    surface_frame_token,
    ts,
    dur,
    layer_name,
    jank_type as app_jank_type,
    present_type,
    upid,
    present_ts - prev_present_ts as interval_ns,
    is_consumer_jank,
    is_steady_stuffing,
    CASE
      WHEN is_consumer_jank IS NULL THEN NULL
      WHEN is_consumer_jank = 0 THEN 0
      WHEN observed_vsync_missed > 0 THEN observed_vsync_missed
      ELSE 1
    END as vsync_missed,
    jank_responsibility
  FROM ranked_jank_rows
  WHERE frame_row_rank = 1
)
-- CONSUMER_JANK_FRAME_CTES_END
SELECT
  printf('%d', frame_id) as frame_id,
  layer_name,
  printf('%d', ts) as ts_str,
  ROUND(ts / 1e9, 3) as ts_sec,
  ROUND(CASE WHEN dur > 0 THEN dur ELSE 0 END / 1e6, 2) as dur_ms,
  vsync_missed + 1 as token_gap,
  vsync_missed,
  ROUND(interval_ns / 1e6, 2) as interval_ms,
  app_jank_type,
  present_type,
  CASE
    WHEN is_consumer_jank IS NULL THEN 'UNASSESSED'
    WHEN vsync_missed <= 1 THEN 'MINOR_JANK'
    WHEN vsync_missed <= 3 THEN 'JANK'
    WHEN vsync_missed <= 7 THEN 'SEVERE_JANK'
    ELSE 'FROZEN'
  END as jank_severity,
  is_consumer_jank,
  CASE
    WHEN jank_responsibility = 'APP' THEN 'app_late'
    WHEN jank_responsibility = 'SF' THEN 'sf_late'
    WHEN jank_responsibility = 'BUFFER_STUFFING' THEN 'buffer_stuffing'
    WHEN jank_responsibility = 'HIDDEN' THEN 'unattributed_consumer_late'
    ELSE 'unknown'
  END as delay_source,
  'display_frame_present_type_hybrid' as evidence_scope,
  'raw_mixed_stuffing_requires_present_gap; unassessed_is_not_smooth; non_stuffing_late_is_framework_signal_not_visible_cadence; inspect_presentation_cadence_audit' as claim_boundary
FROM frame_signals
WHERE is_consumer_jank = 1 OR is_consumer_jank IS NULL
ORDER BY ts
