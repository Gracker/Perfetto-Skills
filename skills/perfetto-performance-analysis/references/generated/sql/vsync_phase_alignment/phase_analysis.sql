-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_phase_alignment.skill.yaml
-- Source SHA-256: aa679a4012ff427342720c41889b1a0f80611cc2773e76cc5875c582d7427d6c
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

WITH vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
vsync_cfg AS (
  SELECT COALESCE(
    CAST(PERCENTILE(interval_ns, 50) AS INTEGER),
    16666667
  ) as period_ns
  FROM vsync_intervals
  WHERE interval_ns BETWEEN 5500000 AND 50000000
),
vsync_events AS (
  SELECT c.ts as vsync_ts
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
  ORDER BY c.ts
),
input_events AS (
  SELECT dispatch_ts as input_ts
  FROM android_input_events
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
),
input_with_vsync AS (
  SELECT
    ie.input_ts,
    (SELECT MAX(v.vsync_ts) FROM vsync_events v WHERE v.vsync_ts <= ie.input_ts) as prev_vsync,
    (SELECT MIN(v.vsync_ts) FROM vsync_events v WHERE v.vsync_ts > ie.input_ts) as next_vsync
  FROM input_events ie
)
SELECT
  printf('%d', input_ts) as input_ts,
  printf('%d', prev_vsync) as nearest_vsync_ts,
  ROUND((input_ts - prev_vsync) / 1e6, 2) as phase_offset_ms,
  ROUND((input_ts - prev_vsync) * 100.0 / (SELECT period_ns FROM vsync_cfg), 1) as phase_ratio_pct,
  ROUND((next_vsync - input_ts) / 1e6, 2) as wait_ms
FROM input_with_vsync
WHERE prev_vsync IS NOT NULL AND next_vsync IS NOT NULL
ORDER BY input_ts
