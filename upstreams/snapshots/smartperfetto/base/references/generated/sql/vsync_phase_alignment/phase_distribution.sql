-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_phase_alignment.skill.yaml
-- Source SHA-256: aa679a4012ff427342720c41889b1a0f80611cc2773e76cc5875c582d7427d6c
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

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
),
input_events AS (
  SELECT dispatch_ts as input_ts
  FROM android_input_events
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
),
phase_offsets AS (
  SELECT
    (ie.input_ts - (SELECT MAX(v.vsync_ts) FROM vsync_events v WHERE v.vsync_ts <= ie.input_ts)) as offset_ns,
    ((SELECT MIN(v.vsync_ts) FROM vsync_events v WHERE v.vsync_ts > ie.input_ts) - ie.input_ts) as wait_ns
  FROM input_events ie
),
valid AS (
  SELECT offset_ns, wait_ns FROM phase_offsets
  WHERE offset_ns IS NOT NULL AND wait_ns IS NOT NULL
    AND offset_ns >= 0 AND wait_ns >= 0
)
SELECT '相位偏移 P50(ms)' as metric, CAST(ROUND(PERCENTILE(offset_ns, 50) / 1e6, 2) AS TEXT) as value FROM valid
UNION ALL
SELECT '相位偏移 P90(ms)', CAST(ROUND(PERCENTILE(offset_ns, 90) / 1e6, 2) AS TEXT) FROM valid
UNION ALL
SELECT 'VSync等待 P50(ms)', CAST(ROUND(PERCENTILE(wait_ns, 50) / 1e6, 2) AS TEXT) FROM valid
UNION ALL
SELECT 'VSync等待 P90(ms)', CAST(ROUND(PERCENTILE(wait_ns, 90) / 1e6, 2) AS TEXT) FROM valid
UNION ALL
SELECT '偏移>75%周期(不利相位)', CAST(ROUND(
  100.0 * (SELECT COUNT(*) FROM valid WHERE offset_ns > (SELECT period_ns FROM vsync_cfg) * 0.75) /
  MAX((SELECT COUNT(*) FROM valid), 1), 1) AS TEXT) || '%' FROM valid
UNION ALL
SELECT '样本数', CAST(COUNT(*) AS TEXT) FROM valid
