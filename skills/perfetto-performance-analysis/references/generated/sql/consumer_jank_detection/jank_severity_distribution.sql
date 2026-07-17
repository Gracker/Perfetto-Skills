-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: 55465b17c1e74abda8e2e04bb70d0c079459a9f4095de2b56b420ac9721ee0c0
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
vsync_events AS (
  SELECT
    c.ts as vsync_ts,
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
buffer_events AS (
  SELECT
    c.ts,
    c.value as buffer_count
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name LIKE '%BufferTX%'
    AND (t.name LIKE '%${package}%' OR '${package}' = '')
    AND ('${end_ts}' = '' OR c.ts <= CAST('${end_ts}' AS INTEGER))
),
vsync_with_buffer AS (
  SELECT
    v.interval_ns,
    (SELECT b.buffer_count
     FROM buffer_events b
     WHERE b.ts <= v.vsync_ts
     ORDER BY b.ts DESC
     LIMIT 1
    ) as buffer_at_vsync
  FROM vsync_events v
  WHERE v.interval_ns IS NOT NULL
),
gap_analysis AS (
  SELECT
    MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) as vsync_missed,
    CASE
      WHEN MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) = 0 THEN 'SMOOTH (gap=1)'
      WHEN MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) = 1 THEN 'MINOR_JANK (gap=2, 跳1帧)'
      WHEN MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) <= 3 THEN 'JANK (gap=3-4, 跳2-3帧)'
      WHEN MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) <= 7 THEN 'SEVERE_JANK (gap=5-8, 跳4-7帧)'
      ELSE 'FROZEN (gap>8, 跳8+帧)'
    END as severity
  FROM vsync_with_buffer
  WHERE buffer_at_vsync IS NOT NULL
)
SELECT
  severity,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) as percentage
FROM gap_analysis
GROUP BY severity
ORDER BY
  CASE severity
    WHEN 'SMOOTH (gap=1)' THEN 1
    WHEN 'MINOR_JANK (gap=2, 跳1帧)' THEN 2
    WHEN 'JANK (gap=3-4, 跳2-3帧)' THEN 3
    WHEN 'SEVERE_JANK (gap=5-8, 跳4-7帧)' THEN 4
    ELSE 5
  END
